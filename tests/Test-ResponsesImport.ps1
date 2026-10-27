$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$temp=Join-Path $env:TMPDIR ('psaoai-import-'+[guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
try {
    Copy-Item "$root/PSAOAI.ps*" $temp
    Copy-Item "$root/Public","$root/Private","$root/images" $temp -Recurse
    # Keep the real setter and version discovery. Guard persistent writes before RED
    # can execute them; unlike the old no-op setter this cannot mask the prompt bug.
    $setter=Get-Content "$temp/Private/Set-EnvironmentVariable.ps1" -Raw
    $setter=$setter.Replace('[System.Environment]::SetEnvironmentVariable(', 'Assert-NoEnvironmentWrite(')
    Set-Content "$temp/Private/Set-EnvironmentVariable.ps1" $setter
    $initializer=Get-Content "$temp/Public/Initialize-PSAOAIConfiguration.ps1" -Raw
    $initializer=$initializer.Replace('[System.Environment]::SetEnvironmentVariable(', 'Assert-NoEnvironmentWrite(')
    Set-Content "$temp/Public/Initialize-PSAOAIConfiguration.ps1" $initializer
    function global:Assert-NoEnvironmentWrite { $global:writeCalls++; throw 'Unexpected environment write' }
    function global:Set-Item { $global:writeCalls++; throw 'Unexpected Set-Item during import' }
    function global:Read-Host { $global:promptCalls++; throw 'Unexpected interactive prompt during import' }
    function global:Find-Module { param($Name,$Repository,$ErrorAction) $global:findCalls++; [pscustomobject]@{Version=[version]'0.7.0'} }
    # Simulate failed discovery: the genuine Get-APIVersion catches it and returns null.
    function global:Invoke-RestMethod { $global:restCalls++; throw 'Offline discovery unavailable' }
    function global:Invoke-WebRequest { throw 'Unexpected network command during import' }
    # Unix has no User persistence. Replace only the User read boundary in this
    # disposable copy; real Get-EnvironmentVariable precedence remains exercised.
    $getter=Get-Content "$temp/Private/Get-EnvironmentVariable.ps1" -Raw
    $getter=$getter.Replace('[System.Environment]::GetEnvironmentVariable($VariableName, "User")', '$global:syntheticUser[$VariableName]')
    Set-Content "$temp/Private/Get-EnvironmentVariable.ps1" $getter
    $expected=@('Invoke-PSAOAIChatCompletion','Invoke-PSAOAICompletion','Invoke-PSAOAIDalle3','Invoke-PSAOAIEmbedding','Get-APIVersion','Clear-PSAOAIEnv','Get-PSAOAIEnv','Invoke-PSAOAIResponse','Initialize-PSAOAIConfiguration') | Sort-Object
    $cases=@(
        @{Name='absent'; Process=$null; User=$null; API=$null; Show=$true},
        @{Name='enabled'; Process='1'; User=$null; API='2024-synthetic'; Show=$true},
        @{Name='process suppression'; Process='0'; User=$null; API=$null; Show=$false},
        @{Name='User suppression'; Process=$null; User='0'; API=$null; Show=$false},
        @{Name='Process precedence'; Process='1'; User='0'; API=$null; Show=$true}
    )
    foreach ($case in $cases) {
        $global:findCalls=0; $global:restCalls=0; $global:writeCalls=0; $global:promptCalls=0
        $global:syntheticUser=@{PSAOAI_BANNER=$case.User}
        $env:PSAOAI_BANNER=$case.Process
        $env:PSAOAI_API_AZURE_OPENAI_APIVERSION=$case.API
        $before=$env:PSAOAI_API_AZURE_OPENAI_APIVERSION
        $output=Import-Module "$temp/PSAOAI.psd1" -Force -PassThru 6>&1
        $module=Get-Module PSAOAI
        $text=($output | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | Out-String)
        if ($global:promptCalls -ne 0 -or $global:writeCalls -ne 0) { throw "Import prompted or wrote: $($case.Name)" }
        if ($global:findCalls -ne 1 -or $global:restCalls -ne 0) { throw 'Unexpected bootstrap/discovery calls' }
        if ($env:PSAOAI_API_AZURE_OPENAI_APIVERSION -cne $before) { throw 'Import overwrote API version' }
        if (Compare-Object $expected ((Get-Command -Module PSAOAI).Name | Sort-Object)) { throw 'Exports differ' }
        $note=(Import-PowerShellDataFile "$temp/PSAOAI.psd1").PrivateData.PSData.ReleaseNotes
        if ($case.Show) {
            if (-not $text.Contains($note) -or $text -notmatch '0\.7\.0' -or $text -notmatch 'Invoke-PSAOAIResponse' -or $text -notmatch 'Get-PSAOAIEnv') { throw "Missing latest note: $($case.Name)" }
            if ($text -match '0\.6\.[0-9]|Performed additional packaging cleanup') { throw 'Historical notes leaked' }
        } elseif ($text -match 'Welcome|0\.7\.0|Invoke-PSAOAIResponse|PSAOAI_BANNER') { throw "Banner not suppressed: $($case.Name)" }
        foreach ($mode in @('Chat','Completion','Dalle3','Embedding')) {
            $suffix=@{Chat='chat/completions';Completion='completions';Dalle3='images/generations';Embedding='embeddings'}[$mode]
            $url=& $module { param($m) Get-PSAOAIUrl -Endpoint 'https://synthetic.test/' -Deployment 'model /x' -APIVersion '2024-test' -Mode $m } $mode
            if ($url -cne "https://synthetic.test/openai/deployments/model%20%2Fx/$suffix`?api-version=2024-test") { throw 'Legacy URL changed' }
        }
        Remove-Module PSAOAI
        Write-Host "PASS import $($case.Name): nine exports; four URLs; no prompt, discovery or writes"
    }
    Write-Host 'PASS isolated import: five cases; real import/setter/discovery; User read seam only; PSGallery stub'
} finally {
    Remove-Module PSAOAI -ErrorAction SilentlyContinue
    Remove-Item $temp -Recurse -Force
}
