# This function makes an API request and stores the response
function Invoke-PSAOAIApiRequest {
    <#
    .SYNOPSIS
    Sends a POST request to the specified API and stores the response.

    .DESCRIPTION
    The Invoke-ApiRequest function sends a POST request to the API specified by the url parameter. It uses the provided headers and bodyJSON for the request.
    If the request is successful, it returns the response. If an error occurs during the request, it writes bounded diagnostics (when a logfile is provided) and rethrows the error.

    .PARAMETER url
    Specifies the URL for the API request. This parameter is mandatory.

    .PARAMETER headers
    Specifies the headers for the API request. This parameter is mandatory.

    .PARAMETER bodyJSON
    Specifies the body for the API request. This parameter is mandatory.

    .EXAMPLE
    Invoke-ApiRequest -url $url -headers $headers -bodyJSON $bodyJSON

    .OUTPUTS
    If successful, it outputs the response from the API request. If an error occurs, it throws.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$url, # The URL for the API request

        [Parameter(Mandatory = $true)]
        [hashtable]$headers, # The headers for the API request

        [Parameter(Mandatory = $true)]
        [string]$bodyJSON, # The body for the API request

        [Parameter(Mandatory = $false)]
        $timeout = 60,

        [Parameter(Mandatory = $false)]
        [string]$logfile,

        [Parameter(Mandatory = $false)]
        [hashtable]$DiagnosticMetadata
    )

    $job = $null

    # Try to send the API request and handle any errors
    try {
        $job = Start-Job -ScriptBlock {
            param($url, $headers, $bodyJSON, $timeout)
            try {
                $response = Invoke-WebRequest -Uri $url -Method POST -Headers $headers -Body $bodyJSON -TimeoutSec $timeout -ErrorAction Stop -ContentType 'application/json; charset=utf-8'
                $utf8 = [System.Text.Encoding]::UTF8
                $reader = New-Object System.IO.StreamReader($response.RawContentStream, $utf8)
                $jsonString = $reader.ReadToEnd()
                $reader.Close()
                $responseJson = $jsonString | ConvertFrom-Json
                return $responseJson
            }
            catch {
                $message = $_.Exception.Message
                $errorBody = $null
                $statusCode = $null
                $reasonPhrase = $null
                $exceptionType = $_.Exception.GetType().FullName

                if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                    $errorBody = $_.ErrorDetails.Message
                }

                if ($_.Exception.Response) {
                    try {
                        if ($_.Exception.Response.StatusCode) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                        }
                    }
                    catch {
                    }

                    try {
                        if ($_.Exception.Response.ReasonPhrase) {
                            $reasonPhrase = [string]$_.Exception.Response.ReasonPhrase
                        }
                    }
                    catch {
                    }

                    try {
                        if ((-not $errorBody) -and $_.Exception.Response.Content) {
                            $errorBody = $_.Exception.Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                        }
                    }
                    catch {
                    }

                    try {
                        if ((-not $errorBody) -and $_.Exception.Response.GetResponseStream) {
                            $stream = $_.Exception.Response.GetResponseStream()
                            if ($stream) {
                                $reader = New-Object System.IO.StreamReader($stream)
                                $errorBody = $reader.ReadToEnd()
                                $reader.Close()
                            }
                        }
                    }
                    catch {
                    }
                }

                return [pscustomobject]@{
                    __PSAOAIRequestFailed = $true
                    Message                = $message
                    ErrorBody              = $errorBody
                    StatusCode             = $statusCode
                    ReasonPhrase           = $reasonPhrase
                    ExceptionType          = $exceptionType
                }
            }
        } -ArgumentList $url, $headers, $bodyJSON, $timeout

        # Write verbose output for the job
        Write-Verbose ("Job: $($job | ConvertTo-Json)")

        # Wait for the job to finish
        while (($job.JobStateInfo.State -eq 'Running') -or ($job.JobStateInfo.State -eq 'NotStarted')) {
            Write-Host "." -NoNewline -ForegroundColor Blue
            Start-Sleep -Milliseconds 1000
        }
        Write-Host ""

        # If the job failed unexpectedly, write the error message and throw
        if ($job.JobStateInfo.State -eq 'Failed') {
            $jobFailureMessage = $job.ChildJobs[0].JobStateInfo.Reason.Message
            if ($logfile) {
                Write-LogMessage -Message "HTTP request job failed before returning diagnostics: $jobFailureMessage" -Level "ERROR" -LogFile $logfile
            }
            throw $jobFailureMessage
        }

        # Receive the job result
        $response = Receive-Job -Id $job.Id -Wait -ErrorAction Stop

        if ($response -and $response.PSObject.Properties.Name -contains '__PSAOAIRequestFailed' -and $response.__PSAOAIRequestFailed) {
            $requestId = $null
            if ($DiagnosticMetadata -and $DiagnosticMetadata.ContainsKey('requestId')) {
                $requestId = [string]$DiagnosticMetadata['requestId']
            }

            $errorSummary = "HTTP request failed: $($response.Message)"
            if ($response.StatusCode) {
                $errorSummary += " (status=$($response.StatusCode)"
                if ($response.ReasonPhrase) {
                    $errorSummary += ", reason=$($response.ReasonPhrase)"
                }
                $errorSummary += ")"
            }

            if ($logfile) {
                $logDirectory = Split-Path -Path $logfile -Parent
                $logBaseName = [System.IO.Path]::GetFileNameWithoutExtension($logfile)
                $requestSuffix = if ($requestId) { ".request-$requestId" } else { "" }
                $errorBodyPath = Join-Path $logDirectory "$logBaseName$requestSuffix.http-error.txt"
                $errorMetaPath = Join-Path $logDirectory "$logBaseName$requestSuffix.http-error-meta.json"

                $errorMeta = [ordered]@{
                    timestamp     = (Get-Date).ToString('o')
                    requestId     = $requestId
                    url           = $url
                    statusCode    = $response.StatusCode
                    reasonPhrase  = $response.ReasonPhrase
                    exceptionType = $response.ExceptionType
                    message       = $response.Message
                    logfile       = $logfile
                    errorBodyPath = $errorBodyPath
                    metadata      = $DiagnosticMetadata
                }

                if ($response.ErrorBody) {
                    Set-Content -Path $errorBodyPath -Value $response.ErrorBody -Encoding UTF8
                    Write-LogMessage -Message "Diagnostic raw HTTP error body saved to: $errorBodyPath" -LogFile $logfile
                }
                else {
                    Write-LogMessage -Message "Diagnostic raw HTTP error body was empty or unavailable." -Level "WARNING" -LogFile $logfile
                }

                $errorMeta | ConvertTo-Json -Depth 8 | Set-Content -Path $errorMetaPath -Encoding UTF8
                Write-LogMessage -Message "Diagnostic HTTP error metadata saved to: $errorMetaPath" -LogFile $logfile
                Write-LogMessage -Message $errorSummary -Level "ERROR" -LogFile $logfile
            }

            if ($response.ErrorBody) {
                throw "$errorSummary`n$response.ErrorBody"
            }

            throw $errorSummary
        }

        if ($logfile) {
            $requestId = $null
            if ($DiagnosticMetadata -and $DiagnosticMetadata.ContainsKey('requestId')) {
                $requestId = [string]$DiagnosticMetadata['requestId']
            }

            $logDirectory = Split-Path -Path $logfile -Parent
            $logBaseName = [System.IO.Path]::GetFileNameWithoutExtension($logfile)
            $requestSuffix = if ($requestId) { ".request-$requestId" } else { "" }
            $successResponsePath = Join-Path $logDirectory "$logBaseName$requestSuffix.http-success-response.json"
            $successMetaPath = Join-Path $logDirectory "$logBaseName$requestSuffix.http-success-meta.json"

            $successMeta = [ordered]@{
                timestamp           = (Get-Date).ToString('o')
                requestId           = $requestId
                url                 = $url
                responseType        = if ($null -ne $response) { $response.GetType().FullName } else { $null }
                topLevelProperties  = if ($null -ne $response) { @($response.PSObject.Properties.Name) } else { @() }
                logfile             = $logfile
                responseBodyPath    = $successResponsePath
                metadata            = $DiagnosticMetadata
            }

            $response | ConvertTo-Json -Depth 100 | Set-Content -Path $successResponsePath -Encoding UTF8
            $successMeta | ConvertTo-Json -Depth 10 | Set-Content -Path $successMetaPath -Encoding UTF8
            Write-LogMessage -Message "Diagnostic raw HTTP success response saved to: $successResponsePath" -LogFile $logfile
            Write-LogMessage -Message "Diagnostic HTTP success metadata saved to: $successMetaPath" -LogFile $logfile
        }

        # Write verbose output for the response
        Write-Verbose ($response | Out-String)

        # Return the response
        return $response
    }
    # Catch any errors and rethrow after logging
    catch {
        if ($logfile) {
            Write-LogMessage -Message ($_.Exception.Message) -Level "ERROR" -LogFile $logfile
        }
        throw
    }
    finally {
        if ($job) {
            Remove-Job -Id $job.Id -Force -ErrorAction SilentlyContinue
        }
    }
}
