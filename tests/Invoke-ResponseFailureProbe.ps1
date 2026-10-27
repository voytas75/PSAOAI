param([string]$Base,[string]$Mode,[string]$Action,[string]$Simple)
$ErrorActionPreference=$Action
$root=Split-Path $PSScriptRoot -Parent
foreach ($file in @('Private/Get-PSAOAIResponseBody.ps1','Private/Get-PSAOAIResponseText.ps1','Private/Invoke-PSAOAIResponseRequest.ps1','Public/Invoke-PSAOAIResponse.ps1')) { . (Join-Path $root $file) }
$script:API_AZURE_OPENAI_KEY='SYNTHETIC_KEY_VARIABLE'
function Get-EnvironmentVariable { param($VariableName,[switch]$Secure) 'synthetic-key-only' }
function Get-PSAOAIResponseUrl { param($Endpoint) "$Base/$Mode" }
$savedParser=${function:Get-PSAOAIResponseText}
$script:parserCalls=0
function Get-PSAOAIResponseText {
    [CmdletBinding()]param($Response,[switch]$FullResponse)
    $script:parserCalls++
    & $savedParser -Response $Response -FullResponse:$FullResponse
}
$Error.Clear()
$stream=@(); $caught=$null; $after=$false
$call=@{Endpoint='https://synthetic.test';Deployment='synthetic';InputText='synthetic-private-prompt';TimeoutSec=1;SimpleResponse=[bool]::Parse($Simple)}
# No enclosing try under Continue: otherwise PowerShell's statement-terminating
# error is caught by that try and the native default cascade is concealed.
if ($Action -eq 'Continue') {
    Invoke-PSAOAIResponse @call 2>&1 | ForEach-Object { $script:stream+= $_ }
    $after=$true
} else {
    try { $stream=@(Invoke-PSAOAIResponse @call -ErrorAction Stop 2>&1); $after=$true } catch { $caught=$_ }
}
$records=@($stream | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
# Statement-terminating errors can bypass redirected pipeline output; retain
# the actual error record from PowerShell's error stream history in that case.
if (-not $records.Count -and -not $caught -and $Error.Count) { $records=@($Error[0]) }
if ($caught) { $records+=$caught }
[pscustomobject]@{
    ParserCalls=$script:parserCalls; Count=$records.Count; After=$after
    OutputCount=@($stream | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }).Count
    Ids=@($records | ForEach-Object { $_.FullyQualifiedErrorId.Split(',')[0] })
    Messages=@($records | ForEach-Object { $_.Exception.Message })
    Safe=@($records | ForEach-Object { $null -eq $_.TargetObject -and $null -eq $_.Exception.InnerException })
    Rendered=($records | Format-List * -Force | Out-String)+($records.Exception | Format-List * -Force | Out-String)
} | ConvertTo-Json -Depth 10 -Compress
