function Initialize-PSAOAIConfiguration {
    <#
    .SYNOPSIS
    Explicitly configures Azure Responses endpoint and API key for this process only.
    .DESCRIPTION
    Prompts only for missing values. Validates the endpoint before asking for the key
    with Read-Host -AsSecureString. No User/Machine persistence, network call or secret
    output. Process environment holds the plaintext key required by transport; this is
    not encrypted storage. Closing the shell removes this process configuration.
    .EXAMPLE
    Initialize-PSAOAIConfiguration
    #>
    [CmdletBinding()]
    param([string]$Endpoint)
    $secureKey=$null; $plainKey=$null; $bstr=[IntPtr]::Zero
    try {
        if (-not $PSBoundParameters.ContainsKey('Endpoint')) {
            $Endpoint=Get-EnvironmentVariable -VariableName $script:API_AZURE_OPENAI_ENDPOINT -Verbose:$false -Debug:$false
        }
        $writeEndpoint=[string]::IsNullOrWhiteSpace($Endpoint) -or $PSBoundParameters.ContainsKey('Endpoint')
        if ([string]::IsNullOrWhiteSpace($Endpoint)) { $Endpoint=Read-Host -Prompt 'Azure OpenAI HTTPS endpoint (resource root or /openai/v1)' }
        if ([string]::IsNullOrWhiteSpace($Endpoint)) { throw [ArgumentException]::new() }
        $null=Get-PSAOAIResponseUrl -Endpoint $Endpoint
        $plainKey=Get-EnvironmentVariable -VariableName $script:API_AZURE_OPENAI_KEY -Secure -Verbose:$false -Debug:$false
        $writeKey=[string]::IsNullOrWhiteSpace($plainKey)
        if ($writeKey) {
            $secureKey=Read-Host -Prompt 'Azure OpenAI API key (hidden; current process only)' -AsSecureString
            if ($secureKey -isnot [System.Security.SecureString] -or $secureKey.Length -eq 0) { throw [ArgumentException]::new() }
            $bstr=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
            $plainKey=[System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            if ([string]::IsNullOrWhiteSpace($plainKey)) { throw [ArgumentException]::new() }
        }
        # Both values are validated before any write. Never use the legacy persistent setter.
        if ($writeEndpoint) { [System.Environment]::SetEnvironmentVariable($script:API_AZURE_OPENAI_ENDPOINT,$Endpoint,'Process') }
        if ($writeKey) { [System.Environment]::SetEnvironmentVariable($script:API_AZURE_OPENAI_KEY,$plainKey,'Process') }
        [pscustomobject]@{ Configured=$true; Scope='Process'; EndpointConfigured=$true; APIKeyConfigured=$true }
    } catch {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [InvalidOperationException]::new('Configuration was cancelled, invalid or could not be applied. Use Initialize-PSAOAIConfiguration with a valid HTTPS resource endpoint and a nonempty hidden API key.'),
            'PSAOAI.Configuration.SetupFailed','InvalidOperation',$null))
    } finally {
        if ($bstr -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        if ($null -ne $secureKey) { $secureKey.Dispose() }
        $plainKey=$null
    }
}
