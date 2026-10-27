$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$script:passed=0; $script:failed=0
$script:API_AZURE_OPENAI_ENDPOINT='PSAOAI_API_AZURE_OPENAI_ENDPOINT'
$script:API_AZURE_OPENAI_KEY='PSAOAI_API_AZURE_OPENAI_KEY'
# Real lookup with synthetic stores only: never read operator credentials.
$getter=Get-Content "$root/Private/Get-EnvironmentVariable.ps1" -Raw
$getter=$getter.Replace('[System.Environment]::GetEnvironmentVariable($VariableName, "Process")','$script:store[$VariableName]').Replace('[System.Environment]::GetEnvironmentVariable($VariableName, "User")','$null').Replace('[System.Environment]::GetEnvironmentVariable($VariableName, "Machine")','$null').Replace('(Get-Item -Path "Env:$VariableName" -ErrorAction SilentlyContinue).Value','$null')
Invoke-Expression $getter
foreach ($f in @('Get-PSAOAIResponseUrl','Get-PSAOAIResponseBody','Get-PSAOAIResponseText')) { . "$root/Private/$f.ps1" }
. "$root/Public/Invoke-PSAOAIResponse.ps1"
if (Test-Path "$root/Public/Initialize-PSAOAIConfiguration.ps1") {
    $source=Get-Content "$root/Public/Initialize-PSAOAIConfiguration.ps1" -Raw
    Invoke-Expression ($source.Replace('[System.Environment]::SetEnvironmentVariable($script:API_AZURE_OPENAI_ENDPOINT,$Endpoint,''Process'')', 'Write-SyntheticEnvironment $script:API_AZURE_OPENAI_ENDPOINT $Endpoint Process').Replace('[System.Environment]::SetEnvironmentVariable($script:API_AZURE_OPENAI_KEY,$plainKey,''Process'')', 'Write-SyntheticEnvironment $script:API_AZURE_OPENAI_KEY $plainKey Process'))
}
function Write-SyntheticEnvironment($Name,$Value,$Scope) {
    if ($Scope -ne 'Process') { throw 'Persistent write forbidden' }
    $script:writes++; $script:store[$Name]=$Value
}
function Read-Host { param($Prompt,[switch]$AsSecureString)
    $script:prompts++
    if ($AsSecureString) {
        if ($script:cancel) { throw 'synthetic cancellation private marker' }
        return ConvertTo-SecureString $script:secret -AsPlainText -Force
    }
    return $script:endpoint
}
function Invoke-PSAOAIResponseRequest { param($Url,$Headers,$BodyJSON,$TimeoutSec)
    $script:calls++; if ($Headers['api-key'] -cne $script:secret) { throw 'Key roundtrip corrupted' }
    $script:url=$Url
    return ('{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"OK"}]}]}' | ConvertFrom-Json)
}
function Check($Condition) { if (-not $Condition) { throw 'Assertion failed' } }
function Case($Name,[scriptblock]$Body) {
    $script:store=@{}; $script:writes=0; $script:prompts=0; $script:calls=0
    $script:cancel=$false; $script:endpoint='https://synthetic.test/openai/v1'; $script:secret='synthetic-key-Żółć-only'
    try { & $Body; $script:passed++; Write-Host "PASS $Name" } catch { $script:failed++; Write-Host "FAIL $Name : $($_.Exception.Message)" }
}
Case 'explicit setup secret-free status and Process-only writes' {
    $r=Initialize-PSAOAIConfiguration -Verbose -Debug *>&1
    Check ($script:writes -eq 2 -and $script:prompts -eq 2 -and $script:calls -eq 0)
    Check (($r | Out-String) -notmatch 'synthetic-key|Żółć')
    Check ($r.Scope -eq 'Process' -and $r.Configured)
    Check ((Get-EnvironmentVariable $script:API_AZURE_OPENAI_KEY -Secure) -ceq $script:secret)
}
foreach ($missing in @('both','endpoint','key')) {
 Case "default missing-specific $missing without prompts/writes/transport" {
    if ($missing -eq 'endpoint') { $script:store[$script:API_AZURE_OPENAI_KEY]=$script:secret }
    if ($missing -eq 'key') { $script:store[$script:API_AZURE_OPENAI_ENDPOINT]=$script:endpoint }
    $e=$null; try { Invoke-PSAOAIResponse -Deployment model -InputText text } catch { $e=$_ }
    Check ($e.FullyQualifiedErrorId -like 'PSAOAI.Response.ConfigurationError*')
    Check ($e.Exception.Message.Contains('Initialize-PSAOAIConfiguration'))
    Check ($e.Exception.Message.Contains($script:API_AZURE_OPENAI_ENDPOINT) -eq ($missing -ne 'key'))
    Check ($e.Exception.Message.Contains($script:API_AZURE_OPENAI_KEY) -eq ($missing -ne 'endpoint'))
    Check ($script:prompts -eq 0 -and $script:writes -eq 0 -and $script:calls -eq 0)
 }
}
Case 'Interactive setup proceeds once with real lookup Unicode key' {
    Check ((Invoke-PSAOAIResponse -Deployment model -InputText text -Interactive -SimpleResponse) -eq 'OK')
    Check ($script:calls -eq 1 -and $script:writes -eq 2 -and $script:prompts -eq 2)
    Check ($script:url -eq 'https://synthetic.test/openai/v1/responses')
}
Case 'Interactive explicit endpoint requires only secure key' {
    Check ((Invoke-PSAOAIResponse -Endpoint $script:endpoint -Deployment model -InputText text -Interactive -SimpleResponse) -eq 'OK')
    Check ($script:prompts -eq 1 -and $script:calls -eq 1)
}
Case 'configured Interactive does not prompt or write' {
    $script:store[$script:API_AZURE_OPENAI_ENDPOINT]=$script:endpoint; $script:store[$script:API_AZURE_OPENAI_KEY]=$script:secret
    Invoke-PSAOAIResponse -Deployment model -InputText text -Interactive | Out-Null
    Check ($script:prompts -eq 0 -and $script:writes -eq 0 -and $script:calls -eq 1)
}
foreach ($bad in @('http://synthetic.test','https://synthetic.test/other','')) {
 Case "invalid setup endpoint before secret/write/transport [$bad]" {
    $script:endpoint=$bad; $e=$null
    try { Invoke-PSAOAIResponse -Deployment model -InputText text -Interactive } catch { $e=$_ }
    Check ($null -ne $e -and $script:prompts -eq 1 -and $script:writes -eq 0 -and $script:calls -eq 0)
 }
}
Case 'cancelled secure prompt sanitizes error and writes nothing' {
    $script:cancel=$true; $e=$null
    try { Invoke-PSAOAIResponse -Deployment model -InputText text -Interactive } catch { $e=$_ }
    Check ($null -ne $e -and $script:prompts -eq 2 -and $script:writes -eq 0 -and $script:calls -eq 0)
    Check (($e | Format-List * -Force | Out-String) -notmatch 'private marker')
}
Case 'empty key writes nothing and never sends' {
    $script:secret=' '; $e=$null
    try { Invoke-PSAOAIResponse -Deployment model -InputText text -Interactive } catch { $e=$_ }
    Check ($null -ne $e -and $script:prompts -eq 2 -and $script:writes -eq 0 -and $script:calls -eq 0)
}
Case 'mandatory parameters retained and no raw key or persistence parameter' {
    foreach ($n in @('Deployment','InputText')) { Check (@((Get-Command Invoke-PSAOAIResponse).Parameters[$n].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }).Count -gt 0) }
    $c=Get-Command Initialize-PSAOAIConfiguration
    Check (-not $c.Parameters.ContainsKey('APIKey') -and -not $c.Parameters.ContainsKey('Scope'))
}
Write-Host "RESULT passed=$script:passed failed=$script:failed"
if ($script:failed) { exit 1 }
