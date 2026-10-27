[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$script:passed = 0
$script:failed = 0
function Assert-True($Condition) { if (-not $Condition) { throw 'Assertion failed (synthetic fixture only).' } }
function Test-Case($Name, [scriptblock]$Body) {
    try { & $Body; $script:passed++; Write-Host "PASS $Name" }
    catch { $script:failed++; Write-Host "FAIL $Name : $($_.Exception.GetType().Name)" }
}
# Redirect the legacy static User query for RED too: never read real persistent values.
$source = Get-Content (Join-Path $root 'Public/Get-PSAOAIEnv.ps1') -Raw
$source = $source.Replace('[Environment]::GetEnvironmentVariables("user")', '(Get-PSAOAIEnvironmentVariables -Scope User)')
. ([scriptblock]::Create($source))
$script:empty = $false
$script:calls = @()
function Get-PSAOAIEnvironmentVariables {
    param($Scope)
    $script:calls += $Scope
    if ($script:empty) { return @{ OTHER_VARIABLE = 'ignored' } }
    if ($Scope -eq 'Process') {
        # Read only known synthetic names; no real secret enumeration or output.
        return @{ PSAOAI_TEST_DUPLICATE = [Environment]::GetEnvironmentVariable('PSAOAI_TEST_DUPLICATE', 'Process'); PSAOAI_API_AZURE_OPENAI_KEY = 'synthetic-process-key'; PSAOAI_TEST_EMPTY = ''; OTHER_VARIABLE = 'ignored' }
    }
    return @{ PSAOAI_TEST_DUPLICATE = "synthetic-$Scope"; PSAOAI_API_AZURE_OPENAI_KEY = "synthetic-$Scope-key"; PSAOAI_OTHER_API_KEY = ''; OTHER_VARIABLE = 'ignored' }
}
# A new child process owns this synthetic value; no User/Machine mutation.
[Environment]::SetEnvironmentVariable('PSAOAI_TEST_DUPLICATE', 'synthetic-Process', 'Process')
foreach ($scope in @('Process', 'User', 'Machine')) {
    Test-Case "single scope $scope objects and filtering" {
        $script:calls = @()
        $rows = @(Get-PSAOAIEnv -Scope $scope)
        Assert-True ($rows.Count -eq 3)
        Assert-True (($script:calls -join ',') -eq $scope)
        foreach ($row in $rows) {
            Assert-True ($row -is [pscustomobject])
            Assert-True ($row.Scope -eq $scope)
            Assert-True ($row.Name -like 'PSAOAI*')
            Assert-True ($row.PSObject.Properties.Name -contains 'Value')
        }
        Assert-True (($rows | Where-Object Name -eq PSAOAI_TEST_DUPLICATE).Value -eq "synthetic-$scope")
    }
}
Test-Case 'default all scopes preserves duplicate names' {
    $script:calls = @()
    $rows = @(Get-PSAOAIEnv)
    Assert-True ($rows.Count -eq 9)
    Assert-True (($script:calls -join ',') -eq 'Process,User,Machine')
    Assert-True (@($rows | Where-Object Name -eq PSAOAI_TEST_DUPLICATE).Count -eq 3)
}
Test-Case 'all API keys fully masked including empty keys' {
    $rows = @(Get-PSAOAIEnv)
    $keys = @($rows | Where-Object Name -match 'API.*KEY')
    Assert-True ($keys.Count -eq 5)
    foreach ($key in $keys) { Assert-True ($key.Value -ceq '****'); Assert-True ($key.Info -notmatch 'encoded|encrypted') }
}
Test-Case 'empty ordinary value remains data' {
    $rows = @(Get-PSAOAIEnv -Scope Process)
    Assert-True (($rows | Where-Object Name -eq PSAOAI_TEST_EMPTY).Value -ceq '')
}
Test-Case 'empty result emits information not a data row' {
    $script:empty = $true
    try {
        $messages = @()
        $rows = @(Get-PSAOAIEnv -InformationVariable messages -InformationAction SilentlyContinue)
        Assert-True ($rows.Count -eq 0)
        Assert-True ($messages.Count -eq 1)
        Assert-True ("$($messages[0])" -match 'No PSAOAI environment variables')
    } finally { $script:empty = $false }
}
Test-Case 'invalid scope rejected before lookup' {
    $script:calls = @()
    $caught = $false
    try { Get-PSAOAIEnv -Scope Invalid | Out-Null } catch [System.Management.Automation.ParameterBindingException] { $caught = $true }
    Assert-True $caught
    Assert-True ($script:calls.Count -eq 0)
}
Test-Case 'case insensitive scope accepted and canonicalized' {
    $rows = @(Get-PSAOAIEnv -Scope process)
    Assert-True ($rows[0].Scope -ceq 'Process')
}
Write-Host "RESULT passed=$script:passed failed=$script:failed"
if ($script:failed) { exit 1 }
