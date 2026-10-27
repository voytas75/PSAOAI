function Get-PSAOAIResponseText {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()]$Response, [switch]$FullResponse)
    $failure = $null
    if ($null -eq $Response -or $Response -isnot [pscustomobject] -or
        $Response.status -cnotin @('completed','incomplete','failed')) { $failure='ProtocolError' }
    elseif ($Response.status -ceq 'failed' -or $null -ne $Response.error) { $failure='Failed' }
    elseif ($Response.output -isnot [array]) { $failure='ProtocolError' }
    $text = [System.Text.StringBuilder]::new()
    $refused = $false
    if (-not $failure) {
        foreach ($item in $Response.output) {
            if ($null -eq $item -or $item -isnot [pscustomobject] -or $item.type -isnot [string]) { $failure='ProtocolError'; break }
            if ($item.type -ceq 'message' -and $item.content -isnot [array]) { $failure='ProtocolError'; break }
            foreach ($block in $item.content) {
                if ($null -eq $block -or $block -isnot [pscustomobject] -or $block.type -isnot [string]) { $failure='ProtocolError'; break }
                if ($block.type -ceq 'refusal') { $refused=$true }
                if ($block.type -ceq 'output_text') {
                    if ($block.text -isnot [string]) { $failure='ProtocolError'; break }
                    [void]$text.Append($block.text)
                }
            }
        }
    }
    if (-not $failure -and $refused) {
        if ($FullResponse) { Write-Warning 'PSAOAI.Response.Refused: response contains a refusal.' }
        else { $failure='Refused' }
    }
    if (-not $failure -and $Response.status -ceq 'incomplete') { Write-Warning 'PSAOAI.Response.Incomplete: response is partial.' }
    if (-not $failure -and -not $FullResponse -and $text.Length -eq 0) { $failure='NoText' }
    if ($failure) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [InvalidOperationException]::new("Responses result rejected ($failure)."),
            "PSAOAI.Response.$failure", 'InvalidResult', $null))
    }
    if ($FullResponse) { return $Response }
    return $text.ToString()
}
