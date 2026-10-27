# Internal enumeration seam: keeps scope inventory distinct from effective lookup.
function Get-PSAOAIEnvironmentVariables {
    param([System.EnvironmentVariableTarget]$Scope)
    [Environment]::GetEnvironmentVariables($Scope)
}

<#
.SYNOPSIS
Lists PSAOAI environment variables by storage scope.
.DESCRIPTION
Returns separate rows from Process, User and Machine by default, preserving
names present in multiple scopes rather than applying effective precedence.
API key values are fully masked without decoding or assuming encryption.
.PARAMETER Scope
Optional single scope: Process, User or Machine. Omit to list all three.
.OUTPUTS
System.Management.Automation.PSCustomObject. Name, Value, Scope and Info.
.EXAMPLE
Get-PSAOAIEnv
.EXAMPLE
Get-PSAOAIEnv -Scope Process
.NOTES
User and Machine inventories depend on platform support; on Unix they may be empty.
#>
function Get-PSAOAIEnv {
    [CmdletBinding()]
    param(
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope
    )

    $scopes = if ($PSBoundParameters.ContainsKey('Scope')) {
        @(([System.EnvironmentVariableTarget]$Scope).ToString())
    } else {
        @('Process', 'User', 'Machine')
    }
    $found = $false
    foreach ($target in $scopes) {
        $variables = Get-PSAOAIEnvironmentVariables -Scope $target
        foreach ($variable in ($variables.GetEnumerator() | Sort-Object Key)) {
            if ($variable.Key -notlike 'PSAOAI*') { continue }
            $found = $true
            $isApiKey = $variable.Key -match 'API.*KEY'
            [pscustomobject]@{
                Name = $variable.Key
                Value = if ($isApiKey) { '****' } else { $variable.Value }
                Scope = $target
                Info = if ($isApiKey) { 'API key value masked' } else { 'N/A' }
            }
        }
    }
    if (-not $found) {
        Write-Information "No PSAOAI environment variables found in scope(s): $($scopes -join ', ')." -InformationAction Continue
    }
}
