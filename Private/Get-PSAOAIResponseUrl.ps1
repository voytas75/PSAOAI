function Get-PSAOAIResponseUrl {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Endpoint)
    $uri = $null
    if (-not [uri]::TryCreate($Endpoint, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or -not $uri.Host -or $uri.UserInfo -or
        $uri.Query -or $uri.Fragment -or $Endpoint.Contains('?') -or $Endpoint.Contains('#') -or
        $uri.AbsolutePath.TrimEnd('/') -cnotin @('', '/openai/v1')) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [ArgumentException]::new('Responses endpoint must be an HTTPS resource root or /openai/v1 base without credentials, query or fragment.'),
            'PSAOAI.Response.InvalidEndpoint', 'InvalidArgument', $null))
    }
    return $uri.GetLeftPart([UriPartial]::Authority) + '/openai/v1/responses'
}
