function Get-PSAOAIResponseBody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Deployment,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$InputText,
        [ValidateNotNullOrEmpty()][string]$Instructions,
        [ValidateRange(1,2147483647)][int]$MaxOutputTokens
    )
    $body = @{ model=$Deployment; input=$InputText; store=$false; stream=$false; background=$false }
    if ($PSBoundParameters.ContainsKey('Instructions')) { $body.instructions=$Instructions }
    if ($PSBoundParameters.ContainsKey('MaxOutputTokens')) { $body.max_output_tokens=$MaxOutputTokens }
    return $body
}
