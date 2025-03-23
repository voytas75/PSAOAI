<#
.SYNOPSIS
This function retrieves all user environment variables that start with "PSAOAI".

.DESCRIPTION
The Get-PSAOAIEnv function uses the .NET Environment class to get all user environment variables. 
It then filters these variables to only include those that start with "PSAOAI". 
The resulting list of variables is then formatted for display, with sensitive keys partially masked.

.OUTPUTS
System.Collections.DictionaryEntry. Outputs a list of user environment variables that start with "PSAOAI".

.NOTES
    Author: Wojciech Napierala
    Date: 2024-04
#>
function Get-PSAOAIEnv {
    param ()

    # Retrieve and filter environment variables starting with "PSAOAI"
    $envVars = ([Environment]::GetEnvironmentVariables("user")).GetEnumerator() | 
        Where-Object { $_.Key -like "PSAOAI*" }

    foreach ($envVar in $envVars) {
        if ($envVar.Key -eq 'PSAOAI_API_AZURE_OPENAI_KEY') {
            # Partially mask the API key for security
            # Note: PSAOAI_API_AZURE_OPENAI_KEY is an encoded version of the real API key
            $keyValue = $envVar.Value
            $maskedValue = if ($keyValue.Length -gt 8) {
                $keyValue.Substring(0, 4) + "****" + $keyValue.Substring($keyValue.Length - 4, 4)
            } else {
                '****'
            }
    
            [PSCustomObject]@{
                Name  = $envVar.Key
                Value = $maskedValue
                Info  = 'Encoded version of the real API key'
            }
        } else {
            [PSCustomObject]@{
                Name  = $envVar.Key
                Value = $envVar.Value
                Info  = 'N/A'
            }
        }
    }
}