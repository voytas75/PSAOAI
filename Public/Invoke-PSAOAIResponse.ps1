function Invoke-PSAOAIResponse {
    <#
    .SYNOPSIS
    Sends one synchronous text request to Azure Responses v1.
    .DESCRIPTION
    Returns the full REST result unless SimpleResponse is selected. Does not store,
    stream, retry, follow redirects or log payloads. Qualified offline on PowerShell 7.6.8.
    .EXAMPLE
    Invoke-PSAOAIResponse -Endpoint https://example.openai.azure.com -Deployment model -InputText 'Hello' -MaxOutputTokens 512 -SimpleResponse
    #>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()][string]$Endpoint,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Deployment,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$InputText,
        [ValidateNotNullOrEmpty()][string]$Instructions,
        [ValidateRange(1,2147483647)][int]$MaxOutputTokens,
        [ValidateRange(1,2147483647)][int]$TimeoutSec=60,
        [switch]$SimpleResponse
    )
    $bodyArgs = @{ Deployment=$Deployment; InputText=$InputText }
    foreach ($name in @('Instructions','MaxOutputTokens')) {
        if ($PSBoundParameters.ContainsKey($name)) { $bodyArgs[$name]=$PSBoundParameters[$name] }
    }
    $body = Get-PSAOAIResponseBody @bodyArgs
    try {
        if (-not $PSBoundParameters.ContainsKey('Endpoint')) {
            $Endpoint = Get-EnvironmentVariable -VariableName $script:API_AZURE_OPENAI_ENDPOINT -Verbose:$false -Debug:$false
        }
        $key = Get-EnvironmentVariable -VariableName $script:API_AZURE_OPENAI_KEY -Secure -Verbose:$false -Debug:$false
    } catch {
        $key = $null
    }
    if ([string]::IsNullOrEmpty($Endpoint) -or [string]::IsNullOrEmpty($key)) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [InvalidOperationException]::new('Responses endpoint and API key configuration are required; no interactive configuration is performed.'),
            'PSAOAI.Response.ConfigurationError', 'InvalidOperation', $null))
    }
    $url = Get-PSAOAIResponseUrl -Endpoint $Endpoint
    $result = Invoke-PSAOAIResponseRequest -Url $url -Headers @{'api-key'=$key} -BodyJSON ($body | ConvertTo-Json -Depth 20 -Compress) -TimeoutSec $TimeoutSec
    Get-PSAOAIResponseText -Response $result -FullResponse:(-not $SimpleResponse)
}
