function Invoke-PSAOAIResponse {
    <#
    .SYNOPSIS
    Sends one synchronous text request to Azure Responses v1.
    .DESCRIPTION
    Returns the full REST result unless SimpleResponse is selected. Does not store,
    stream, retry, follow redirects or log payloads. Qualified offline on PowerShell 7.6.8.
    .PARAMETER Interactive
    Explicitly opt into hidden-key Process-only setup when configuration is missing.
    Default mode names missing variables without configuration prompts. PowerShell
    mandatory Deployment/InputText prompts are preserved in both modes.
    .EXAMPLE
    Invoke-PSAOAIResponse -Endpoint https://example.openai.azure.com -Deployment model -InputText 'Hello' -MaxOutputTokens 512 -SimpleResponse
    #>
    [CmdletBinding()]
    param(
        [string]$Endpoint,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Deployment,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$InputText,
        [ValidateNotNullOrEmpty()][string]$Instructions,
        [ValidateRange(1,2147483647)][int]$MaxOutputTokens,
        [ValidateRange(1,2147483647)][int]$TimeoutSec=60,
        [switch]$SimpleResponse,
        [switch]$Interactive
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
    $missing=@()
    if ([string]::IsNullOrWhiteSpace($Endpoint)) { $missing += $script:API_AZURE_OPENAI_ENDPOINT }
    if ([string]::IsNullOrWhiteSpace($key)) { $missing += $script:API_AZURE_OPENAI_KEY }
    if ($missing.Count -gt 0 -and $Interactive) {
        $setupArgs=@{}
        if (-not [string]::IsNullOrWhiteSpace($Endpoint)) { $setupArgs.Endpoint=$Endpoint }
        $null=Initialize-PSAOAIConfiguration @setupArgs
        if ([string]::IsNullOrWhiteSpace($Endpoint)) {
            $Endpoint=Get-EnvironmentVariable -VariableName $script:API_AZURE_OPENAI_ENDPOINT -Verbose:$false -Debug:$false
        }
        $key=Get-EnvironmentVariable -VariableName $script:API_AZURE_OPENAI_KEY -Secure -Verbose:$false -Debug:$false
        $missing=@()
        if ([string]::IsNullOrWhiteSpace($Endpoint)) { $missing += $script:API_AZURE_OPENAI_ENDPOINT }
        if ([string]::IsNullOrWhiteSpace($key)) { $missing += $script:API_AZURE_OPENAI_KEY }
    }
    if ($missing.Count -gt 0) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [InvalidOperationException]::new("Missing Responses configuration: $($missing -join ', '). Run Initialize-PSAOAIConfiguration for hidden-key Process-only setup, or explicitly select -Interactive. Default mode does not prompt for configuration."),
            'PSAOAI.Response.ConfigurationError', 'InvalidOperation', $null))
    }
    $url = Get-PSAOAIResponseUrl -Endpoint $Endpoint
    try {
        # Stop the nested statement error before a null result reaches the parser.
        $result = Invoke-PSAOAIResponseRequest -Url $url -Headers @{'api-key'=$key} -BodyJSON ($body | ConvertTo-Json -Depth 20 -Compress) -TimeoutSec $TimeoutSec -ErrorAction Stop
    } catch {
        # Preserve the transport's fresh sanitized record and caller ErrorAction.
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Get-PSAOAIResponseText -Response $result -FullResponse:(-not $SimpleResponse)
}
