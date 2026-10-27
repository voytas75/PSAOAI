[CmdletBinding()]
param([switch]$SelfTest, [switch]$SkipLoopback)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$script:passed = 0
$script:failed = 0
$script:skipped = 0
function Assert-Equal($Actual, $Expected) {
    if ($Actual -cne $Expected) { throw "Expected '$Expected'; actual '$Actual'" }
}
function Test-Case([string]$Name, [scriptblock]$Body) {
    try { & $Body; $script:passed++; Write-Host "PASS $Name" }
    catch { $script:failed++; Write-Host "FAIL $Name : $($_.Exception.Message)" }
}
if ($SelfTest) {
    Test-Case 'runner accepts equality' { Assert-Equal 'a' 'a' }
    Test-Case 'assertion rejects inequality' {
        $caught = $false
        try { Assert-Equal 'a' 'b' } catch { $caught = $true }
        Assert-Equal $caught $true
    }
} else {
    # No module import: production bootstrap performs network/configuration actions.
    foreach ($relative in @(
        'Private/Get-PSAOAIResponseUrl.ps1',
        'Private/Get-PSAOAIResponseBody.ps1',
        'Private/Get-PSAOAIResponseText.ps1',
        'Public/Invoke-PSAOAIResponse.ps1'
    )) {
        $path = Join-Path $root $relative
        if (Test-Path $path) { . $path }
    }
    Test-Case 'root endpoint maps to Responses v1' {
        Assert-Equal (Get-PSAOAIResponseUrl -Endpoint 'https://synthetic.openai.azure.com/') 'https://synthetic.openai.azure.com/openai/v1/responses'
    }
    Test-Case 'v1 base is not duplicated' {
        Assert-Equal (Get-PSAOAIResponseUrl -Endpoint 'https://synthetic.openai.azure.com/openai/v1/') 'https://synthetic.openai.azure.com/openai/v1/responses'
    }
    foreach ($invalid in @('http://example.test', 'https://user:secret@example.test', 'https://example.test/?x=1', 'https://example.test/#fragment', 'https://example.test/other')) {
        Test-Case "reject URL $invalid" {
            # A missing function is not a successful validation test.
            Get-Command Get-PSAOAIResponseUrl -ErrorAction Stop | Out-Null
            $caught = $false
            try { Get-PSAOAIResponseUrl -Endpoint $invalid | Out-Null } catch { $caught = $true }
            Assert-Equal $caught $true
        }
    }
    Test-Case 'body maps deployment and explicit defaults' {
        $body = Get-PSAOAIResponseBody -Deployment 'synthetic-deployment' -InputText 'Zażółć' -MaxOutputTokens 512
        $json = $body | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        Assert-Equal $json.model 'synthetic-deployment'
        Assert-Equal $json.input 'Zażółć'
        Assert-Equal $json.store $false
        Assert-Equal $json.stream $false
        Assert-Equal $json.background $false
        Assert-Equal $json.max_output_tokens 512
        Assert-Equal ($json.PSObject.Properties.Name -contains 'temperature') $false
    }
    foreach ($tokens in @(0, -1)) {
        Test-Case "reject output token budget $tokens" {
            Get-Command Get-PSAOAIResponseBody -ErrorAction Stop | Out-Null
            $caught = $false
            try { Get-PSAOAIResponseBody -Deployment 'synthetic' -InputText 'text' -MaxOutputTokens $tokens | Out-Null } catch { $caught = $true }
            Assert-Equal $caught $true
        }
    }
    Test-Case 'omitted optional fields stay omitted' {
        $body = Get-PSAOAIResponseBody -Deployment 'synthetic' -InputText 'text'
        $json = $body | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        Assert-Equal ($json.PSObject.Properties.Name -contains 'max_output_tokens') $false
        Assert-Equal ($json.PSObject.Properties.Name -contains 'instructions') $false
    }
    Test-Case 'text parser skips reasoning and preserves block order' {
        $response = '{"status":"completed","output":[{"type":"reasoning","summary":[]},{"type":"message","content":[{"type":"output_text","text":"Zaż"},{"type":"output_text","text":"ółć"}]}]}' | ConvertFrom-Json
        Assert-Equal (Get-PSAOAIResponseText -Response $response) 'Zażółć'
    }
    Test-Case 'refusal including mixed text is not plain success' {
        Get-Command Get-PSAOAIResponseText -ErrorAction Stop | Out-Null
        $response = '{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"partial"},{"type":"refusal","refusal":"synthetic"}]}]}' | ConvertFrom-Json
        $id = ''
        try { Get-PSAOAIResponseText -Response $response | Out-Null } catch { $id = $_.FullyQualifiedErrorId.Split(',')[0] }
        Assert-Equal $id 'PSAOAI.Response.Refused'
    }
    Test-Case 'incomplete without text reports NoText' {
        Get-Command Get-PSAOAIResponseText -ErrorAction Stop | Out-Null
        $response = '{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output":[]}' | ConvertFrom-Json
        $id = ''
        try { Get-PSAOAIResponseText -Response $response | Out-Null } catch { $id = $_.FullyQualifiedErrorId.Split(',')[0] }
        Assert-Equal $id 'PSAOAI.Response.NoText'
    }
    foreach ($sample in @(
        @{ Name = 'failed'; Json = '{"status":"failed","error":{"code":"synthetic"},"output":[]}'; Id = 'PSAOAI.Response.Failed' },
        @{ Name = 'unknown status'; Json = '{"status":"queued","output":[]}'; Id = 'PSAOAI.Response.ProtocolError' },
        @{ Name = 'completed without text'; Json = '{"status":"completed","output":[]}'; Id = 'PSAOAI.Response.NoText' }
    )) {
        Test-Case $sample.Name {
            Get-Command Get-PSAOAIResponseText -ErrorAction Stop | Out-Null
            $id = ''
            try { Get-PSAOAIResponseText -Response ($sample.Json | ConvertFrom-Json) | Out-Null } catch { $id = $_.FullyQualifiedErrorId.Split(',')[0] }
            Assert-Equal $id $sample.Id
        }
    }
    Test-Case 'incomplete text is preserved with warning' {
        $warnings = @()
        $response = '{"status":"incomplete","output":[{"type":"message","content":[{"type":"output_text","text":"partial"}]}]}' | ConvertFrom-Json
        Assert-Equal (Get-PSAOAIResponseText -Response $response -WarningVariable warnings -WarningAction SilentlyContinue) 'partial'
        Assert-Equal ($warnings.Count -gt 0) $true
    }
    foreach ($field in @('Deployment', 'InputText', 'Instructions')) {
        Test-Case "reject empty body field $field" {
            Get-Command Get-PSAOAIResponseBody -ErrorAction Stop | Out-Null
            $arguments = @{ Deployment = 'synthetic'; InputText = 'text' }
            $arguments[$field] = ''
            $caught = $false
            try { Get-PSAOAIResponseBody @arguments | Out-Null } catch { $caught = $true }
            Assert-Equal $caught $true
        }
    }
    Test-Case 'explicit instructions are retained' {
        $body = Get-PSAOAIResponseBody -Deployment 'synthetic' -InputText 'text' -Instructions 'Krótko'
        $json = $body | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        Assert-Equal $json.instructions 'Krótko'
    }
    Test-Case 'missing status is protocol error' {
        Get-Command Get-PSAOAIResponseText -ErrorAction Stop | Out-Null
        $id = ''
        try { Get-PSAOAIResponseText -Response ([pscustomobject]@{output=@()}) | Out-Null } catch { $id = $_.FullyQualifiedErrorId.Split(',')[0] }
        Assert-Equal $id 'PSAOAI.Response.ProtocolError'
    }
    # Synthetic transport boundary: only caller wiring, NOT real HTTP qualification.
    # Dependency contract: Url, Headers, BodyJSON, TimeoutSec; one decoded REST object.
    $script:transportCalls = 0
    $script:transportMode = 'success'
    $script:fixture = '{"id":"resp_synthetic","status":"completed","error":null,"incomplete_details":null,"usage":{"input_tokens":3,"output_tokens":2},"output":[{"type":"message","content":[{"type":"output_text","text":"text"}]}],"future_field":{"keep":true}}' | ConvertFrom-Json
    function Invoke-PSAOAIResponseRequest {
        [CmdletBinding()]
        param([string]$Url, [hashtable]$Headers, [string]$BodyJSON, [int]$TimeoutSec)
        $script:transportCalls++
        $script:capturedRequest = @{ Url=$Url; Headers=$Headers; Body=($BodyJSON | ConvertFrom-Json); Timeout=$TimeoutSec }
        if ($script:transportMode -ne 'success') {
            $record = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Synthetic sanitized transport failure'),
                $script:transportMode,
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null)
            $PSCmdlet.ThrowTerminatingError($record)
        }
        return $script:fixture
    }
    # Auth lookup fixture; no real environment/secret reads.
    $script:API_AZURE_OPENAI_KEY = 'SYNTHETIC_KEY_VARIABLE'
    function Get-EnvironmentVariable { param($VariableName, [switch]$Secure) return 'synthetic-key-only' }
    function Test-UserEnvironmentVariable { param($VariableName) return $true }
    Test-Case 'full cmdlet result preserves unknown fields and usage' {
        Get-Command Invoke-PSAOAIResponse -ErrorAction Stop | Out-Null
        $script:transportCalls = 0
        $result = Invoke-PSAOAIResponse -Endpoint 'https://synthetic.openai.azure.com' -Deployment 'synthetic' -InputText 'text' -TimeoutSec 12
        Assert-Equal $script:transportCalls 1
        Assert-Equal $result.id 'resp_synthetic'
        Assert-Equal $result.usage.input_tokens 3
        Assert-Equal $result.future_field.keep $true
        Assert-Equal ($result.PSObject.Properties.Name -contains 'RunspaceId') $false
        Assert-Equal $script:capturedRequest.Url 'https://synthetic.openai.azure.com/openai/v1/responses'
        Assert-Equal $script:capturedRequest.Timeout 12
        Assert-Equal $script:capturedRequest.Headers['api-key'] 'synthetic-key-only'
        Assert-Equal $script:capturedRequest.Body.model 'synthetic'
    }
    Test-Case 'invalid input does not reach transport' {
        Get-Command Invoke-PSAOAIResponse -ErrorAction Stop | Out-Null
        $script:transportCalls = 0
        $caught = $false
        try { Invoke-PSAOAIResponse -Endpoint 'https://synthetic.openai.azure.com' -Deployment 'synthetic' -InputText '' | Out-Null } catch { $caught = $true }
        Assert-Equal $caught $true
        Assert-Equal $script:transportCalls 0
    }
    foreach ($failure in @('PSAOAI.Response.HttpError','PSAOAI.Response.Timeout')) {
        Test-Case "caller preserves sanitized $failure" {
            Get-Command Invoke-PSAOAIResponse -ErrorAction Stop | Out-Null
            $script:transportMode = $failure
            $record = $null
            try { Invoke-PSAOAIResponse -Endpoint 'https://synthetic.openai.azure.com' -Deployment 'synthetic' -InputText 'synthetic-private-prompt' | Out-Null } catch { $record = $_ }
            finally { $script:transportMode = 'success' }
            Assert-Equal ($null -ne $record) $true
            Assert-Equal $record.FullyQualifiedErrorId.Split(',')[0] $failure
            $rendered = $record | Out-String
            Assert-Equal ($rendered.Contains('synthetic-private-prompt')) $false
            Assert-Equal ($rendered.Contains('synthetic-key-only')) $false
        }
    }
    foreach ($sample in @(
        @{status='completed'; output=@()},
        @{status='incomplete'; output=@(); incomplete_details=@{reason='synthetic'}},
        @{status='completed'; output=@([pscustomobject]@{type='message';content=@([pscustomobject]@{type='refusal';refusal='synthetic-private-prompt'})})}
    )) {
        Test-Case "full mode preserves $($sample.status) including empty/refusal result" {
            $script:fixture=[pscustomobject]$sample
            $warnings=@()
            $r=Invoke-PSAOAIResponse -Endpoint 'https://synthetic.test' -Deployment synthetic -InputText text -WarningVariable warnings -WarningAction SilentlyContinue
            Assert-Equal $r.status $sample.status
            if ($sample.status -eq 'incomplete' -or $sample.output.Count) { Assert-Equal ($warnings.Count -gt 0) $true }
        }
    }
    foreach ($json in @('{"status":"completed","output":{}}','{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":42}]}]}','{"status":"completed","error":{"message":"synthetic-private-prompt"},"output":[]}')) {
        Test-Case 'malformed result/nonempty error is terminating and sanitized' {
            $id=''; $record=$null
            try { Get-PSAOAIResponseText -Response ($json | ConvertFrom-Json) -FullResponse | Out-Null } catch { $record=$_; $id=$_.FullyQualifiedErrorId.Split(',')[0] }
            Assert-Equal ($id -in @('PSAOAI.Response.ProtocolError','PSAOAI.Response.Failed')) $true
            Assert-Equal (($record | Out-String).Contains('synthetic-private-prompt')) $false
        }
    }
    Test-Case 'cmdlet has bounded MVP parameters' {
        $command = Get-Command Invoke-PSAOAIResponse -ErrorAction Stop
        foreach ($name in @('Endpoint','Deployment','InputText','Instructions','MaxOutputTokens','TimeoutSec','SimpleResponse')) {
            Assert-Equal $command.Parameters.ContainsKey($name) $true
        }
        foreach ($name in @('InputItems','ReasoningEffort','Temperature','TopP')) {
            Assert-Equal $command.Parameters.ContainsKey($name) $false
        }
        $attributes = $command.Parameters['InputText'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
        foreach ($attribute in $attributes) { Assert-Equal $attribute.ValueFromPipeline $false }
    }
    Test-Case 'caller SimpleResponse and optional fields use explicit endpoint' {
        $script:fixture='{"status":"completed","output":[{"type":"reasoning"},{"type":"message","content":[{"type":"output_text","text":"A"}]},{"type":"message","content":[{"type":"output_text","text":"B"}]}]}'|ConvertFrom-Json
        Assert-Equal (Invoke-PSAOAIResponse -Endpoint 'https://explicit.test' -Deployment synthetic -InputText text -Instructions instruction -MaxOutputTokens 5 -SimpleResponse) 'AB'
        Assert-Equal $script:capturedRequest.Body.instructions 'instruction'
        Assert-Equal $script:capturedRequest.Body.max_output_tokens 5
        Assert-Equal $script:capturedRequest.Url 'https://explicit.test/openai/v1/responses'
        Assert-Equal $script:capturedRequest.Timeout 60
    }
    Test-Case 'missing configuration is noninteractive before transport' {
        $saved=${function:Get-EnvironmentVariable}
        try {
            function Get-EnvironmentVariable { param($VariableName,[switch]$Secure) return $null }
            $script:transportCalls=0
            $id=''
            try { Invoke-PSAOAIResponse -Deployment synthetic -InputText text | Out-Null } catch { $id=$_.FullyQualifiedErrorId.Split(',')[0] }
            Assert-Equal $id 'PSAOAI.Response.ConfigurationError'
            Assert-Equal $script:transportCalls 0
        } finally { ${function:Get-EnvironmentVariable}=$saved }
    }
    Test-Case 'zero timeout rejected before transport' {
        $script:transportCalls=0; $caught=$false
        try { Invoke-PSAOAIResponse -Endpoint 'https://synthetic.test' -Deployment synthetic -InputText text -TimeoutSec 0 | Out-Null } catch { $caught=$true }
        Assert-Equal $caught $true
        Assert-Equal $script:transportCalls 0
    }
    # Restore the real synchronous transport after caller-boundary unit tests.
    . "$root/Private/Invoke-PSAOAIResponseRequest.ps1"
    $pythonPath = $null
    if (-not $SkipLoopback) {
        foreach ($name in @('python3', 'python')) {
            $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($command) {
                try {
                    & $command.Source -c 'import sys; sys.exit(0 if sys.version_info.major == 3 else 1)' 2>$null
                    if ($LASTEXITCODE -eq 0) { $pythonPath = $command.Source; break }
                } catch { }
            }
        }
    }
    if (-not $pythonPath) {
        $script:skipped += 11
        Write-Host 'SKIP 11 loopback tests: Python 3 unavailable or -SkipLoopback selected; real HTTP transport is not qualified by this run.'
    } else {
    $psi=[System.Diagnostics.ProcessStartInfo]::new($pythonPath)
    $psi.ArgumentList.Add("$PSScriptRoot/response_http_fixture.py")
    $psi.RedirectStandardOutput=$true
    $psi.RedirectStandardError=$true
    $psi.UseShellExecute=$false
    $server=[System.Diagnostics.Process]::Start($psi)
    try {
        $lineTask=$server.StandardOutput.ReadLineAsync()
        if (-not $lineTask.Wait(10000)) { throw 'Loopback fixture startup timeout' }
        $port=[int]$lineTask.Result
        $base="http://127.0.0.1:$port"
        $arguments=@{ Headers=@{'api-key'='synthetic-key-only'}; BodyJSON=(@{model='synthetic';input='Zażółć synthetic-private-prompt';store=$false;stream=$false;background=$false}|ConvertTo-Json -Compress); TimeoutSec=1 }
        Test-Case 'real HTTP POST JSON and UTF8 round trip' {
            $result=Invoke-PSAOAIResponseRequest @arguments -Url "$base/openai/v1/responses"
            Assert-Equal $result.received.input 'Zażółć synthetic-private-prompt'
            Assert-Equal $result.received.store $false
            Assert-Equal (Get-PSAOAIResponseText -Response $result) 'Zażółć'
        }
        foreach ($mode in @('400','401','429','500','redirect','timeout','invalid-json','invalid-utf8')) {
            Test-Case "real transport sanitized $mode" {
                $record=$null; $diagnostics=@()
                try { $diagnostics=@(Invoke-PSAOAIResponseRequest @arguments -Url "$base/$mode" -Verbose -Debug *>&1) } catch { $record=$_ }
                $expected=if ($mode -eq 'timeout') {'Timeout'} elseif ($mode -like 'invalid-*') {'ProtocolError'} else {'HttpError'}
                Assert-Equal $record.FullyQualifiedErrorId.Split(',')[0] "PSAOAI.Response.$expected"
                Assert-Equal ($null -eq $record.TargetObject) $true
                Assert-Equal ($null -eq $record.Exception.InnerException) $true
                $rendered=($record | Format-List * -Force | Out-String)+($record.Exception | Format-List * -Force | Out-String)+($diagnostics | Out-String)
                foreach ($marker in @('synthetic-key-only','synthetic-private-prompt','not-json')) { Assert-Equal $rendered.Contains($marker) $false }
            }
        }
        Test-Case 'real transport rejects singleton JSON array root' {
            $record=$null
            try { Invoke-PSAOAIResponseRequest @arguments -Url "$base/array-json" | Out-Null } catch { $record=$_ }
            Assert-Equal ($null -ne $record) $true
            Assert-Equal $record.FullyQualifiedErrorId.Split(',')[0] 'PSAOAI.Response.ProtocolError'
        }
        Test-Case 'server confirms no redirect replay or automatic retries' {
            $stats=Invoke-RestMethod "$base/stats"
            Assert-Equal $stats.Count 10
            Assert-Equal (@($stats | Where-Object path -eq '/redirect-target').Count) 0
            foreach ($entry in $stats) {
                Assert-Equal $entry.method 'POST'
                Assert-Equal $entry.key 'synthetic-key-only'
                Assert-Equal ($entry.content_type -match 'application/json; charset=utf-8') $true
            }
        }
    } finally {
        if (-not $server.HasExited) { $server.Kill($true); $server.WaitForExit() }
        $server.Dispose()
    }
    } # optional Python loopback group
    Test-Case 'isolated full import and legacy exports/URLs' {
        & pwsh -NoLogo -NoProfile -File "$PSScriptRoot/Test-ResponsesImport.ps1"
        Assert-Equal $LASTEXITCODE 0
    }
}
Write-Host "RESULT passed=$script:passed failed=$script:failed skipped=$script:skipped"
if ($script:failed -gt 0) { exit 1 }
exit 0
