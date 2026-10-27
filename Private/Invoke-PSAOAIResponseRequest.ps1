function Invoke-PSAOAIResponseRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][hashtable]$Headers,
        [Parameter(Mandatory)][string]$BodyJSON,
        [ValidateRange(1,2147483647)][int]$TimeoutSec=60
    )
    # HttpClient avoids PowerShell web-cmdlet verbose/error payload diagnostics.
    # No default credentials, proxy, redirects, retries or background jobs.
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $handler.UseProxy = $false
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
    $cancel = [System.Threading.CancellationTokenSource]::new()
    $request = $null
    $response = $null
    $failure = $null
    $message = $null
    try {
        $cancel.CancelAfter([TimeSpan]::FromSeconds($TimeoutSec))
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $Url)
        foreach ($name in $Headers.Keys) { [void]$request.Headers.TryAddWithoutValidation($name, [string]$Headers[$name]) }
        $request.Content = [System.Net.Http.StringContent]::new($BodyJSON, [System.Text.UTF8Encoding]::new($false), 'application/json')
        $response = $client.SendAsync($request, $cancel.Token).GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            $failure = 'HttpError'
            $message = "Responses HTTP request failed (status $([int]$response.StatusCode))."
            if ([int]$response.StatusCode -eq 401) {
                $message += ' Authentication was not accepted. Verify locally that the endpoint and API key belong to the same Azure resource, that the key is current, and that local API-key authentication is enabled for that resource. Do not share the key or raw response body.'
            }
        } else {
            $bytes = $response.Content.ReadAsByteArrayAsync($cancel.Token).GetAwaiter().GetResult()
            try {
                $json = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
                $result = ConvertFrom-Json -InputObject $json -Depth 100 -NoEnumerate -ErrorAction Stop
                if ($result -is [array] -or $result -isnot [pscustomobject]) { throw 'Invalid root' }
            } catch { $failure='ProtocolError'; $message='Responses HTTP result is not a valid UTF-8 JSON object.' }
        }
    } catch {
        if ($cancel.IsCancellationRequested) { $failure='Timeout'; $message='Responses request timed out.' }
        else { $failure='HttpError'; $message='Responses HTTP transport failed.' }
    } finally {
        if ($null -ne $response) { $response.Dispose() }
        if ($null -ne $request) { $request.Dispose() }
        $cancel.Dispose()
        $client.Dispose()
        $handler.Dispose()
    }
    # Create a fresh record outside catch: never retain the HTTP exception or payload.
    if ($failure) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [InvalidOperationException]::new($message), "PSAOAI.Response.$failure", 'InvalidOperation', $null))
    }
    return $result
}
