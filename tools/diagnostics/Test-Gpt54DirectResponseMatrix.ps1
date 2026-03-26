[CmdletBinding()]
param(
    [string]$Endpoint = 'https://example.openai.azure.com',
    [string]$ApiVersion = '2025-04-01-preview',
    [string]$Deployment = 'gpt-5.4',
    [string]$ApiKey,
    [string]$ApiKeyEnvVar = 'PSAOAI_API_AZURE_OPENAI_KEY',
    [string]$OutputRoot,
    [int]$TimeoutSec = 120,
    [switch]$SkipHttp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Save-TextArtifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowNull()][AllowEmptyString()][string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -Path $parent)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }

    if ($null -eq $Content) {
        $Content = ''
    }

    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Save-JsonArtifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Data,
        [int]$Depth = 20
    )

    $json = $Data | ConvertTo-Json -Depth $Depth
    Save-TextArtifact -Path $Path -Content $json
}

function Resolve-ApiKeyValue {
    param(
        [string]$DirectApiKey,
        [string]$EnvVarName
    )

    if (-not [string]::IsNullOrWhiteSpace($DirectApiKey)) {
        return $DirectApiKey.Trim()
    }

    $raw = [System.Environment]::GetEnvironmentVariable($EnvVarName, 'Process')
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $raw = [System.Environment]::GetEnvironmentVariable($EnvVarName, 'User')
    }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $raw = [System.Environment]::GetEnvironmentVariable($EnvVarName, 'Machine')
    }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    $trimmed = $raw.Trim()

    if ($trimmed -match '^01000000d08c9ddf') {
        try {
            $secureValue = $trimmed | ConvertTo-SecureString -ErrorAction Stop
            $credential = New-Object System.Management.Automation.PSCredential('ignored', $secureValue)
            return $credential.GetNetworkCredential().Password
        }
        catch {
            return $trimmed
        }
    }

    return $trimmed
}

function Get-ChatUri {
    param(
        [Parameter(Mandatory)][string]$Endpoint,
        [Parameter(Mandatory)][string]$Deployment,
        [Parameter(Mandatory)][string]$ApiVersion
    )

    $normalizedEndpoint = $Endpoint.TrimEnd('/')
    $encodedDeployment = [System.Uri]::EscapeDataString($Deployment)
    return "$normalizedEndpoint/openai/deployments/$encodedDeployment/chat/completions?api-version=$ApiVersion"
}

function New-ReasoningMessages {
    param(
        [Parameter(Mandatory)][string]$DeveloperPrompt,
        [Parameter(Mandatory)][string]$UserPrompt
    )

    return @(
        [ordered]@{
            role = 'developer'
            content = $DeveloperPrompt
        },
        [ordered]@{
            role = 'user'
            content = $UserPrompt
        }
    )
}

function New-ChatMessages {
    param(
        [Parameter(Mandatory)][string]$SystemPrompt,
        [Parameter(Mandatory)][string]$UserPrompt
    )

    return @(
        [ordered]@{
            role = 'system'
            content = $SystemPrompt
        },
        [ordered]@{
            role = 'user'
            content = $UserPrompt
        }
    )
}

function Get-VariantDefinitions {
    $developerPrompt = 'You are a concise assistant. Answer directly in plain text.'
    $systemPrompt = 'You are a concise assistant. Answer directly in plain text.'
    $simpleUser = 'Reply with exactly: pong'
    $codingUser = 'Write one PowerShell function Get-Hello that returns the string hello. Include code only.'

    return @(
        [ordered]@{
            Name = 'reasoning-simple-256'
            RequestShape = 'reasoning developer/user + max_completion_tokens + reasoning_effort'
            Purpose = 'Minimal reasoning-path sanity check with a trivial prompt.'
            Body = [ordered]@{
                messages = (New-ReasoningMessages -DeveloperPrompt $developerPrompt -UserPrompt $simpleUser)
                max_completion_tokens = 256
                reasoning_effort = 'medium'
            }
        },
        [ordered]@{
            Name = 'reasoning-code-512'
            RequestShape = 'reasoning developer/user + max_completion_tokens + reasoning_effort'
            Purpose = 'Short coding-style request on the reasoning-path shape PSAOAI currently uses.'
            Body = [ordered]@{
                messages = (New-ReasoningMessages -DeveloperPrompt $developerPrompt -UserPrompt $codingUser)
                max_completion_tokens = 512
                reasoning_effort = 'medium'
            }
        },
        [ordered]@{
            Name = 'reasoning-code-2048'
            RequestShape = 'reasoning developer/user + max_completion_tokens + reasoning_effort'
            Purpose = 'Same coding-style request with a larger completion budget to detect token-budget gating.'
            Body = [ordered]@{
                messages = (New-ReasoningMessages -DeveloperPrompt $developerPrompt -UserPrompt $codingUser)
                max_completion_tokens = 2048
                reasoning_effort = 'medium'
            }
        },
        [ordered]@{
            Name = 'chat-simple-256'
            RequestShape = 'classic chat system/user + max_tokens'
            Purpose = 'Checks whether the deployment emits normal chat content on a non-reasoning request shape.'
            Body = [ordered]@{
                messages = (New-ChatMessages -SystemPrompt $systemPrompt -UserPrompt $simpleUser)
                temperature = 0.2
                top_p = 1
                stream = $false
                max_tokens = 256
            }
        }
    )
}

function Get-ErrorBodyText {
    param([Parameter(Mandatory)]$ErrorRecord)

    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
        return [string]$ErrorRecord.ErrorDetails.Message
    }

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) {
        return $null
    }

    try {
        if ($response.Content) {
            $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                return $content
            }
        }
    }
    catch {
    }

    try {
        if ($response.GetResponseStream) {
            $stream = $response.GetResponseStream()
            if ($stream) {
                $reader = [System.IO.StreamReader]::new($stream)
                try {
                    $content = $reader.ReadToEnd()
                    if (-not [string]::IsNullOrWhiteSpace($content)) {
                        return $content
                    }
                }
                finally {
                    $reader.Close()
                }
            }
        }
    }
    catch {
    }

    return $null
}

function Get-ParsedSuccessSummary {
    param(
        [AllowNull()]$ParsedResponse,
        [string]$VariantName,
        [string]$RequestBodyPath,
        [string]$RawResponsePath,
        [int]$HttpStatusCode
    )

    $firstChoice = $null
    $message = $null
    $content = $null
    $contentLength = 0
    $contentType = $null
    $serializedContent = $null
    $toolCallsCount = 0
    $annotationsCount = 0
    $messagePropertyNames = @()
    $finishReason = $null
    $reasoningTokens = $null
    $completionTokens = $null
    $promptTokens = $null
    $totalTokens = $null
    $alternateFields = [ordered]@{}

    if ($null -ne $ParsedResponse -and $null -ne $ParsedResponse.choices -and $ParsedResponse.choices.Count -gt 0) {
        $firstChoice = $ParsedResponse.choices[0]
        $finishReason = $firstChoice.finish_reason
        $message = $firstChoice.message

        if ($null -ne $message) {
            $messagePropertyNames = @($message.PSObject.Properties.Name)
            $content = $message.content
            $alternateFields['role'] = $message.role
            $alternateFields['refusal'] = $message.refusal

            if ($null -ne $message.tool_calls) {
                $toolCallsCount = @($message.tool_calls).Count
            }
            if ($null -ne $message.annotations) {
                $annotationsCount = @($message.annotations).Count
            }
        }
    }

    if ($null -eq $content) {
        $contentLength = 0
        $contentType = $null
    }
    elseif ($content -is [string]) {
        $contentLength = $content.Length
        $contentType = $content.GetType().FullName
    }
    else {
        $serializedContent = $content | ConvertTo-Json -Depth 20 -Compress
        $contentLength = $serializedContent.Length
        $contentType = $content.GetType().FullName
    }

    if ($null -ne $ParsedResponse -and $null -ne $ParsedResponse.usage) {
        $completionTokens = $ParsedResponse.usage.completion_tokens
        $promptTokens = $ParsedResponse.usage.prompt_tokens
        $totalTokens = $ParsedResponse.usage.total_tokens
        if ($null -ne $ParsedResponse.usage.completion_tokens_details) {
            $reasoningTokens = $ParsedResponse.usage.completion_tokens_details.reasoning_tokens
        }
    }

    return [ordered]@{
        variant = $VariantName
        status = 'ok'
        requestBodyPath = $RequestBodyPath
        rawHttpResponsePath = $RawResponsePath
        httpStatusCode = $HttpStatusCode
        finishReason = $finishReason
        rawFirstMessageContentLength = $contentLength
        rawFirstMessageContentType = $contentType
        isEmpty = ($contentLength -eq 0)
        rawChoiceMessagePropertyNames = $messagePropertyNames
        rawToolCallsCount = $toolCallsCount
        rawAnnotationsCount = $annotationsCount
        usage = [ordered]@{
            prompt_tokens = $promptTokens
            completion_tokens = $completionTokens
            total_tokens = $totalTokens
            reasoning_tokens = $reasoningTokens
        }
        alternateFields = $alternateFields
    }
}

function Invoke-Variant {
    param(
        [Parameter(Mandatory)]$Variant,
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][hashtable]$Headers,
        [Parameter(Mandatory)][string]$OutputFolder,
        [Parameter(Mandatory)][int]$TimeoutSec,
        [switch]$SkipHttp
    )

    $variantFolder = Join-Path $OutputFolder $Variant.Name
    if (-not (Test-Path -Path $variantFolder)) {
        [void](New-Item -ItemType Directory -Path $variantFolder -Force)
    }

    $requestBodyPath = Join-Path $variantFolder 'request-body.json'
    $variantMetaPath = Join-Path $variantFolder 'variant.json'
    $rawResponsePath = Join-Path $variantFolder 'http-success-response.json'
    $rawErrorPath = Join-Path $variantFolder 'http-error.txt'
    $summaryPath = Join-Path $variantFolder 'summary.json'

    $bodyJson = $Variant.Body | ConvertTo-Json -Depth 20
    Save-TextArtifact -Path $requestBodyPath -Content $bodyJson
    Save-JsonArtifact -Path $variantMetaPath -Data ([ordered]@{
        name = $Variant.Name
        requestShape = $Variant.RequestShape
        purpose = $Variant.Purpose
        uri = $Uri
    })

    if ($SkipHttp) {
        $summary = [ordered]@{
            variant = $Variant.Name
            status = 'skipped'
            requestBodyPath = $requestBodyPath
            rawHttpResponsePath = $null
            httpStatusCode = $null
            finishReason = $null
            rawFirstMessageContentLength = $null
            rawFirstMessageContentType = $null
            isEmpty = $null
            rawChoiceMessagePropertyNames = @()
            rawToolCallsCount = $null
            rawAnnotationsCount = $null
            usage = $null
            alternateFields = $null
        }
        Save-JsonArtifact -Path $summaryPath -Data $summary
        return $summary
    }

    try {
        $response = Invoke-WebRequest -Uri $Uri -Method POST -Headers $Headers -Body $bodyJson -TimeoutSec $TimeoutSec -ContentType 'application/json; charset=utf-8' -ErrorAction Stop
        $rawContent = $response.Content
        Save-TextArtifact -Path $rawResponsePath -Content $rawContent

        $parsed = $null
        try {
            $parsed = $rawContent | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            $summary = [ordered]@{
                variant = $Variant.Name
                status = 'parse-error'
                requestBodyPath = $requestBodyPath
                rawHttpResponsePath = $rawResponsePath
                httpStatusCode = [int]$response.StatusCode
                finishReason = $null
                rawFirstMessageContentLength = $null
                rawFirstMessageContentType = $null
                isEmpty = $null
                rawChoiceMessagePropertyNames = @()
                rawToolCallsCount = $null
                rawAnnotationsCount = $null
                usage = $null
                alternateFields = [ordered]@{
                    parseError = $_.Exception.Message
                }
            }
            Save-JsonArtifact -Path $summaryPath -Data $summary
            return $summary
        }

        $summary = Get-ParsedSuccessSummary -ParsedResponse $parsed -VariantName $Variant.Name -RequestBodyPath $requestBodyPath -RawResponsePath $rawResponsePath -HttpStatusCode ([int]$response.StatusCode)
        Save-JsonArtifact -Path $summaryPath -Data $summary
        return $summary
    }
    catch {
        $errorBody = Get-ErrorBodyText -ErrorRecord $_
        $statusCode = $null
        try {
            if ($_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
        }
        catch {
        }

        Save-TextArtifact -Path $rawErrorPath -Content ($(if ($errorBody) { $errorBody } else { $_ | Out-String }))

        $summary = [ordered]@{
            variant = $Variant.Name
            status = 'http-error'
            requestBodyPath = $requestBodyPath
            rawHttpResponsePath = $rawErrorPath
            httpStatusCode = $statusCode
            finishReason = $null
            rawFirstMessageContentLength = $null
            rawFirstMessageContentType = $null
            isEmpty = $null
            rawChoiceMessagePropertyNames = @()
            rawToolCallsCount = $null
            rawAnnotationsCount = $null
            usage = $null
            alternateFields = [ordered]@{
                errorMessage = $_.Exception.Message
            }
        }
        Save-JsonArtifact -Path $summaryPath -Data $summary
        return $summary
    }
}

function Save-MarkdownSummary {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Results,
        [Parameter(Mandatory)][string]$Uri
    )

    $lines = @(
        '# gpt-5.4 direct response matrix',
        '',
        "- URI: $Uri",
        "- Generated: $(Get-Date -Format o)",
        '',
        '| Variant | Status | HTTP | Finish | Content length | Content type | Empty | Reasoning tokens | Request body | Raw response |',
        '|---|---|---:|---|---:|---|---|---:|---|---|'
    )

    foreach ($result in $Results) {
        $usageReasoningTokens = if ($null -ne $result.usage) { $result.usage.reasoning_tokens } else { $null }
        $lines += "| $($result.variant) | $($result.status) | $($result.httpStatusCode) | $($result.finishReason) | $($result.rawFirstMessageContentLength) | $($result.rawFirstMessageContentType) | $($result.isEmpty) | $usageReasoningTokens | $($result.requestBodyPath) | $($result.rawHttpResponsePath) |"
    }

    Save-TextArtifact -Path $Path -Content ($lines -join [Environment]::NewLine)
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $OutputRoot = Join-Path $repoRoot "temp/gpt54-direct-response-matrix/$timestamp"
}

if (-not (Test-Path -Path $OutputRoot)) {
    [void](New-Item -ItemType Directory -Path $OutputRoot -Force)
}

$resolvedApiKey = Resolve-ApiKeyValue -DirectApiKey $ApiKey -EnvVarName $ApiKeyEnvVar
if (-not $SkipHttp -and [string]::IsNullOrWhiteSpace($resolvedApiKey)) {
    throw "API key not found. Pass -ApiKey explicitly or set $ApiKeyEnvVar."
}

$uri = Get-ChatUri -Endpoint $Endpoint -Deployment $Deployment -ApiVersion $ApiVersion
$headers = @{
    'Content-Type' = 'application/json; charset=utf-8'
    'OpenAI-Debug' = 'true'
}
if (-not [string]::IsNullOrWhiteSpace($resolvedApiKey)) {
    $headers['api-key'] = $resolvedApiKey
}

$runMeta = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    endpoint = $Endpoint
    apiVersion = $ApiVersion
    deployment = $Deployment
    uri = $uri
    outputRoot = $OutputRoot
    skipHttp = [bool]$SkipHttp
    apiKeyResolved = -not [string]::IsNullOrWhiteSpace($resolvedApiKey)
    variantNames = @((Get-VariantDefinitions).Name)
}
Save-JsonArtifact -Path (Join-Path $OutputRoot 'run-meta.json') -Data $runMeta

$results = @()
foreach ($variant in (Get-VariantDefinitions)) {
    Write-Host "== Running $($variant.Name)" -ForegroundColor Cyan
    $result = Invoke-Variant -Variant $variant -Uri $uri -Headers $headers -OutputFolder $OutputRoot -TimeoutSec $TimeoutSec -SkipHttp:$SkipHttp
    $results += [pscustomobject]$result
}

Save-JsonArtifact -Path (Join-Path $OutputRoot 'matrix-summary.json') -Data $results
Save-MarkdownSummary -Path (Join-Path $OutputRoot 'matrix-summary.md') -Results $results -Uri $uri

$results | Format-Table variant, status, httpStatusCode, finishReason, rawFirstMessageContentLength, rawFirstMessageContentType, isEmpty -AutoSize
Write-Host "Artifacts written to: $OutputRoot" -ForegroundColor Green
