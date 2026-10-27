$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$script:findCalls=0
$script:restCalls=0
$script:setCalls=0
# A temporary module copy replaces ONLY the configuration writer, which would
# otherwise overwrite a parent-scope mock during module dot-sourcing.
$temp=Join-Path $env:TMPDIR ('psaoai-import-'+[guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
try {
    Copy-Item "$root/PSAOAI.ps*" $temp
    Copy-Item "$root/Public","$root/Private" $temp -Recurse
    @'
function Set-EnvironmentVariable { param($VariableName,$VariableValue,$PromptMessage)
    $global:importSetCalls++
    if ($VariableName -ne 'PSAOAI_API_AZURE_OPENAI_APIVERSION' -or $VariableValue -ne '2024-01-01-preview') { throw 'Unexpected bootstrap configuration' }
}
'@ | Set-Content "$temp/Private/Set-EnvironmentVariable.ps1"
    $global:importSetCalls=0
    function global:Find-Module { param($Name,$Repository,$ErrorAction) $script:findCalls++; [pscustomobject]@{Version=[version]'0.6.5'} }
    function global:Invoke-RestMethod { param($Uri,$Method) $script:restCalls++; [pscustomobject]@{type='dir';Name='2024-01-01-preview'} }
    function global:Invoke-WebRequest { throw 'Unexpected network command during import' }
    function global:Read-Host { throw 'Unexpected interactive prompt during import' }
    $env:PSAOAI_BANNER='0'
    Import-Module "$temp/PSAOAI.psd1" -Force
    $expected=@('Invoke-PSAOAIChatCompletion','Invoke-PSAOAICompletion','Invoke-PSAOAIDalle3','Invoke-PSAOAIEmbedding','Get-APIVersion','Clear-PSAOAIEnv','Get-PSAOAIEnv','Invoke-PSAOAIResponse') | Sort-Object
    $actual=(Get-Command -Module PSAOAI).Name | Sort-Object
    if (Compare-Object $expected $actual) { throw 'Exports differ' }
    if ($script:findCalls -ne 1 -or $script:restCalls -ne 1 -or $global:importSetCalls -ne 1) { throw "Isolation hooks not exercised: $script:findCalls/$script:restCalls/$global:importSetCalls" }
    $module=Get-Module PSAOAI
    foreach ($mode in @('Chat','Completion','Dalle3','Embedding')) {
        $suffix=@{Chat='chat/completions';Completion='completions';Dalle3='images/generations';Embedding='embeddings'}[$mode]
        $url=& $module { param($m) Get-PSAOAIUrl -Endpoint 'https://synthetic.test/' -Deployment 'model /x' -APIVersion '2024-test' -Mode $m } $mode
        if ($url -cne "https://synthetic.test/openai/deployments/model%20%2Fx/$suffix`?api-version=2024-test") { throw 'Legacy URL changed' }
    }
    Write-Host 'PASS isolated import: eight exports; four legacy URLs; Find-Module=1 REST=1 config-write-stub=1; no real network/configuration writes'
} finally {
    Remove-Module PSAOAI -ErrorAction SilentlyContinue
    Remove-Item $temp -Recurse -Force
}
