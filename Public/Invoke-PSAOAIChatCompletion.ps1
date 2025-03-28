function Invoke-PSAOAIChatCompletion {
    <#
    .SYNOPSIS
    This function enables communication with an Azure OpenAI chatbot by sending an API request and retrieving the chatbot's response.

    .DESCRIPTION
    Invoke-PSAOAIChatCompletion is a function that establishes a connection with an Azure OpenAI chatbot by sending an API request and receiving the chatbot's response. It allows users to customize their messages and adjust parameters such as temperature, frequency penalty, and others to influence the chatbot's responses.

    .PARAMETER APIVersion
    Specifies the version of the Azure OpenAI API to be used.

    .PARAMETER Endpoint
    Defines the endpoint URL for the Azure OpenAI API.

    .PARAMETER Deployment
    Specifies the name of the OpenAI deployment to be used.

    .PARAMETER User
    Identifies the user initiating the API request.

    .PARAMETER Temperature
    Modifies the temperature parameter for the API request, influencing the randomness of the chatbot's responses.

    .PARAMETER N
    Sets the number of messages to be generated for the API request.

    .PARAMETER FrequencyPenalty
    Modifies the frequency penalty parameter for the API request, influencing the chatbot's preference for less frequently used words.

    .PARAMETER PresencePenalty
    Modifies the presence penalty parameter for the API request, influencing the chatbot's preference for contextually relevant words.

    .PARAMETER TopP
    Modifies the top-p parameter for the API request, influencing the diversity of the chatbot's responses.

    .PARAMETER Stop
    Sets the stop parameter for the API request, indicating when the chatbot should stop generating a response.

    .PARAMETER Stream
    Modifies the stream parameter for the API request, determining whether the chatbot should stream its responses.

    .PARAMETER SystemPromptFilePath
    Specifies the path of the file containing the system prompt.
    
    .PARAMETER SystemPrompt
    Identifies the system prompt.

    .PARAMETER OneTimeUserPrompt
    Identifies a one-time user prompt.

    .PARAMETER logfile
    Identifies the log file.

    .PARAMETER usermessage
    Identifies the user message.

    .PARAMETER usermessagelogfile
    Identifies the user message log file.

    .PARAMETER Precise
    Indicates whether the precise parameter is enabled.

    .PARAMETER Creative
    Indicates whether the creative parameter is enabled.

    .PARAMETER simpleresponse
    Indicates whether the simpleresponse parameter is enabled.

    .PARAMETER TimeOut
    Timeout in seconds.

    .EXAMPLE
    PS C:\> Invoke-PSAOAIChatCompletion -APIVersion "2023-06-01-preview" -Endpoint "https://example.openai.azure.com" -Deployment "example_model_gpt35_!" -User "BobbyK" -Temperature 0.6 -N 1 -FrequencyPenalty 0 -PresencePenalty 0 -TopP 0 -Stop $null -Stream $false

    This example demonstrates how to send an API request to an Azure OpenAI chatbot and receive the response message.

    .NOTES
    Author: Wojciech Napierala
    Date:   2023-06-27
    
    .LINK
    https://learn.microsoft.com/en-us/azure/ai-services/openai/
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 1, Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$usermessage,
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$SystemPrompt,
        [Parameter(Mandatory = $false)]
        [string]$SystemPromptFileName,
        [Parameter(Position = 3, Mandatory = $false)]
        [switch]$OneTimeUserPrompt,
        [Parameter(Position = 2, Mandatory = $false)]
        [ValidateSet("UltraPrecise", "Precise", "Focused", "Balanced", "Informative", "Creative", "Surreal")]
        [string]$Mode,
        [double]$Temperature = 0.5,
        [double]$TopP = 0.5,
        [Parameter(Mandatory = $false)]
        [string]$logfile,
        [Parameter(Mandatory = $false)]
        [string]$LogFolder,
        [Parameter(Mandatory = $false)]
        [string]$usermessagelogfile,
        [Parameter(Position = 4, Mandatory = $false)]
        [switch]$simpleresponse,
        [Parameter(Mandatory = $false)]
        [string]$APIVersion = $null,
        [Parameter(Mandatory = $false)]
        [string]$Endpoint = $null,
        [Parameter(Position = 6, Mandatory = $false)]
        [string]$Deployment = $null,
        [Parameter(Position = 5, Mandatory = $false)]
        [string]$User = "",
        [Parameter(Mandatory = $false)]
        [int]$N = 1,
        [Parameter(Mandatory = $false)]
        [double]$FrequencyPenalty = 0,
        [Parameter(Mandatory = $false)]
        [double]$PresencePenalty = 0,
        [Parameter(Mandatory = $false)]
        [string]$Stop = $null,
        [Parameter(Mandatory = $false)]
        [bool]$Stream = $true,
        [Parameter(Mandatory = $false)]
        [int] $TimeOut = 240,
        [Parameter(Mandatory = $false)]
        [int] $MaxTokens = 4096,
        [Parameter(Mandatory = $false)]
        [switch]$JSONMode = $false,
        [Parameter(Mandatory = $false)]
        [switch]$o1 = $false,
        [Parameter(Mandatory = $false)]
        [switch]$o3 = $false
    )

    # Function to assemble system and user messages
    function Get-PSAOAIMessages {
        # Function to assemble system and user messages
        param(
            [Parameter(Mandatory = $true)]
            [string]$SystemMessage,

            [Parameter(Mandatory = $true)]
            [string]$UserMessage,

            [Parameter(Mandatory = $false)]
            [bool]$JSONMode = $false
        )

        if ($JSONMode) {
            $SystemMessage += " Only accept JSON responses."
            Write-Verbose "JSONMode"
        }
    
        Write-Verbose "System message in Get-PSAOAIMessages: $SystemMessage"
        Write-Verbose "User message in Get-PSAOAIMessages: $UserMessage"
    
        return @(
            @{
                "role"    = "system"
                "content" = $SystemMessage
            },
            @{
                "role"    = "user"
                "content" = $UserMessage
            }
        )
    }
    
    # Function to assemble system and user messages
    function Get-PSAOAIMessageso1 {
        # Function to assemble system and user messages
        param(
            [Parameter(Mandatory = $true)]
            [string]$UserMessage
        )

        Write-Verbose "User message in Get-PSAOAIMessages: $UserMessage"

        return @(
            @{
                "role"    = "user"
                "content" = $UserMessage
            }
        )
    }

    # Function to output the response message
    function Write-PSAOAIMessage {
        <#
        .SYNOPSIS
        This function outputs the response message to the console.
    
        .DESCRIPTION
        Write-PSAOAIMessage is a function that takes in a content and a stream type and outputs the response message.
        The output format can be simplified by using the -simpleresponse switch.
    
        .PARAMETER content
        The content to be displayed. This parameter is mandatory.
    
        .PARAMETER stream
        The stream type of the content. This parameter is mandatory.
    
        .PARAMETER simpleresponse
        A switch parameter. If used, the function will return only the content, without the stream type.
    
        .EXAMPLE
        Write-PSAOAIMessage -content "Hello, how can I assist you today?" -stream "system"
    
        .EXAMPLE
        Write-PSAOAIMessage -content "Hello, how can I assist you today?" -stream "system" -simpleresponse
    
        .OUTPUTS
        String. This function outputs the response message to the console.
        #>
        param(
            [Parameter(Mandatory = $true)]
            [string]$content, # The content to be displayed
    
            [Parameter(Mandatory = $true)]
            [string]$stream, # The stream type of the content
    
            [switch]$simpleresponse # A switch to simplify the response output
        )
    
        # Check if the simpleresponse switch is used
        if (-not $simpleresponse) {
            # Return the response message with the stream type
            return ("Response assistant ($stream):`n${content}")
        }
        else {
            # Return only the content
            return $content
        }
    }
    
    function Get-PSAOAIPromptFilterResults {
        <#
        .SYNOPSIS
        Displays the results of the prompt filter.

        .DESCRIPTION
        This function takes a response object as input and iterates through the 'prompt_filter_results' property of the object. 
        For each item in 'prompt_filter_results', it extracts the 'content_filter_results' and converts it to a string. 
        The function then outputs the 'content_filter_results' for each 'prompt_index'.

        .PARAMETER response
        A PSCustomObject that contains the prompt filter results to be displayed. This parameter is mandatory.

        .EXAMPLE
        Get-PSAOAIPromptFilterResults -response $response

        .OUTPUTS
        String. Outputs the 'content_filter_results' for each 'prompt_index' in the console.
        #> 
        param(
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$response # The response object containing the prompt filter results
        )
    
        # Print an empty line for better readability
        Write-Host ""
        # Print the title for the output
        Write-Host "Prompt Filter Results:"

        # Iterate through each item in the 'prompt_filter_results' property of the response object
        foreach ($result in $response.prompt_filter_results) {
            # Extract the 'content_filter_results' property from the current item
            $contentFilterResults = $result.content_filter_results

            # Convert the 'content_filter_results' to a string
            $contentFilterObject = $contentFilterResults | Out-String

            # Print the 'content_filter_results' for the current 'prompt_index'
            Write-Host "Results for prompt_index $($result.prompt_index):"
            return $contentFilterObject
        }
    }

    function Get-PSAOAIEnvironmentVariableValue {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$VariableName,
            [Parameter(Mandatory = $true)]
            [string]$PromptMessage,
            [switch]$Secure
        )
 
        $variableValue = [System.Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::User)
 
        while (-not $variableValue) {
            if ($Secure) {
                $variableValue = Read-Host -Prompt $PromptMessage -AsSecureString | ConvertFrom-SecureString
            }
            else {
                $variableValue = Read-Host -Prompt $PromptMessage
            }
            [System.Environment]::SetEnvironmentVariable($VariableName, $variableValue, [System.EnvironmentVariableTarget]::User)
        }
 
        return $variableValue
    }

    #region Main
    while (-not $APIVersion) {
        $APIVersion = Set-EnvironmentVariable -VariableName $script:API_AZURE_OPENAI_APIVERSION -PromptMessage "Please enter the AZURE OpenAI API Version"
    }

    while (-not $Endpoint) {
        # Get the endpoint from the environment variable
        $Endpoint = Set-EnvironmentVariable -VariableName $script:API_AZURE_OPENAI_ENDPOINT -PromptMessage "Please enter the AZURE OpenAI Endpoint"
    }

    while (-not $Deployment) {
        # Get the deployment from the environment variable
        $Deployment = Set-EnvironmentVariable -VariableName $script:API_AZURE_OPENAI_CC_DEPLOYMENT -PromptMessage "Please enter the AZURE OpenAI Deployment"
    }

    while ([string]::IsNullOrEmpty($ApiKey)) {
        $ApiKey = Set-EnvironmentVariable -VariableName $script:API_AZURE_OPENAI_KEY -PromptMessage "Please enter the AZURE OpenAI API Key" -Secure
    }
  

    # Continuously prompt the user for a message until a non-empty message is provided
    while ([string]::IsNullOrEmpty($usermessage)) {
        if ($o1) {
            # Ask for specific input for the o1 scenario
            $usermessage = Read-Host -Prompt "Please enter the user message for the o1 scenario"
        }
        elseif ($o3) {
            # Ask for specific input for the o3 scenario
            $usermessage = Read-Host -Prompt "Please enter the user message for the o3 scenario"
        }
        else {
            # Regular input prompt
            $usermessage = Read-Host -Prompt "Please enter the user message"
        }
    }
    
    # Define a hashtable to map modes to their respective settings
    $modeSettings = @{
        "Precise"      = @{ UltraPrecise = $false; Precise = $true; Focused = $false; Balanced = $false; Informative = $false; Creative = $false; Surreal = $false }
        "Creative"     = @{ UltraPrecise = $false; Precise = $false; Focused = $false; Balanced = $false; Informative = $false; Creative = $true; Surreal = $false }
        "UltraPrecise" = @{ UltraPrecise = $true; Precise = $false; Focused = $false; Balanced = $false; Informative = $false; Creative = $false; Surreal = $false }
        "Focused"      = @{ UltraPrecise = $false; Precise = $false; Focused = $true; Balanced = $false; Informative = $false; Creative = $false; Surreal = $false }
        "Balanced"     = @{ UltraPrecise = $false; Precise = $false; Focused = $false; Balanced = $true; Informative = $false; Creative = $false; Surreal = $false }
        "Informative"  = @{ UltraPrecise = $false; Precise = $false; Focused = $false; Balanced = $false; Informative = $true; Creative = $false; Surreal = $false }
        "Surreal"      = @{ UltraPrecise = $false; Precise = $false; Focused = $false; Balanced = $false; Informative = $false; Creative = $false; Surreal = $true }
    }

    # Apply settings based on the selected mode
    if ($modeSettings.ContainsKey($Mode)) {
        $settings = $modeSettings[$Mode]
        $UltraPrecise = $settings.UltraPrecise
        $Precise = $settings.Precise
        $Focused = $settings.Focused
        $Balanced = $settings.Balanced
        $Informative = $settings.Informative
        $Creative = $settings.Creative
        $Surreal = $settings.Surreal
    }
    else {
        # Default case
        [double]$Temperature = $Temperature
        [double]$TopP = $TopP
    }


    $userWasAsked = $false

    # Adjust parameters based on switches.
    #if ($Creative -or $Precise) {
    if ($UltraPrecise -or $Precise -or $Focused -or $Balanced -or $Informative -or $Creative -or $Surreal) {
        $parameters = Set-ParametersForSwitches -Creative:$Creative -Precise:$Precise -UltraPrecise:$UltraPrecise -Focused:$Focused -Balanced:$Balanced -Informative:$Informative -Surreal:$Surreal
        $Temperature = $parameters['Temperature']
        $TopP = $parameters['TopP']
    }
    elseif ($Temperature -and $TopP) {
        $parameters = @{
            'Temperature' = $Temperature
            'TopP'        = $TopP
        }
    }
    else {
        $parameters = @{
            'Temperature' = $Temperature
            'TopP'        = $TopP
        }
    }

    if ($o1 -or $o3) {
        $stream = $false # stream is set to false for 'o1' or 'o3' mode
    }

    if ($OneTimeUserPrompt) {
        [string]$OneTimeUserPrompt = ($usermessage | out-string)
    }

    $logfileDirectory = Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath $script:modulename
    if ($LogFolder) {
        $logfileDirectory = $LogFolder
    }

    if ($VerbosePreference -eq "Continue") {
        Write-Host "APIVersion: $APIVersion"
        Write-Host "Endpoint: $Endpoint"
        Write-Host "Deployment: $Deployment"
        Write-Host "Mode: $(if($Mode){$Mode}else{"does not exist"})"
        Write-Host "SystemPromptFileName: $(if($SystemPromptFileName){"exists"}else{"does not exist"})"
        Write-Host "SystemPrompt: $(if($SystemPrompt){"exists"}else{"default one"})"
        Write-Host "usermessage: $(if($usermessage){"exists"}else{"does not exist"})"
        Write-Host "OneTimeUserPrompt: $(if($OneTimeUserPrompt){"true"}else{"false"})"
        Write-Host "Temperature: $Temperature"
        Write-Host "TopP: $TopP"
        Write-Host "FrequencyPenalty: $FrequencyPenalty"
        Write-Host "PresencePenalty: $PresencePenalty"
        Write-Host "User: $User"
        Write-Host "N: $N"
        Write-Host "Stop: $(if($stop){"set"}else{"not set"})"
        Write-Host "Stream: $(if($stream){"true"}else{"false"})"
        Write-Host "logfile: $(if($logfile){$logfile}else{"not set"})"
        Write-Host "simpleresponse: $simpleresponse"
        Write-Host "usermessagelogfile: $(if($usermessagelogfile){$usermessagelogfile}else{"does not exist"})"
        Write-Host "LogFolder: $logfileDirectory"
        Write-Host "JSONMOde: $JSONMOde"
    }

    try {
        # Check if usermessage is not set and usermessagelogfile is set
        if (-not $usermessage -and $usermessagelogfile) {
            # If so, read the content of usermessagelogfile and assign it to usermessage
            $usermessage = (get-content $usermessagelogfile | out-string)
        }

        # Check if logfile is not set
        if (-not $logfile) {
        
            if (!(Test-Path -Path $logfileDirectory)) {
                # Create the directory if it does not exist
                New-Item -ItemType Directory -Path $logfileDirectory -Force | Out-Null
            }
    
            $logfileBaseName = ""
            $logfileExtension = ".txt"
            if ($usermessage) {
                $userMessageHash = Get-Hash -InputString $usermessage -HashType MD5
                $logfileBaseName = "$($script:modulename)Chat-usermessage-$userMessageHash-"
                if ($OneTimeUserPrompt) {
                    $logfileBaseName = "$($script:modulename)Chat-usermessage-OneTimeUserPrompt-$userMessageHash-"
                }
            }
            if ($SystemPrompt) {
                $SystemMessageHash = Get-Hash -InputString $SystemPrompt -HashType MD5
                $logfileBaseName += "SystemPrompt-$SystemMessageHash-"
            }
            elseif ($SystemPromptFileName) {
                $logfileBaseName += "SystemPrompt-" + [System.IO.Path]::GetFileNameWithoutExtension($SystemPromptFileName) + "-"
            }

            # Initialize logfileNumber to 1
            $logfileNumber = 1
            # Increment logfileNumber until a unique logfile name is found
            while (Test-Path -Path (Join-Path $logfileDirectory ($logfileBaseName + $logfileNumber + $logfileExtension))) {
                $logfileNumber++
            }
            # Set logfile to the unique logfile name
            $logfile = Join-Path $logfileDirectory ($logfileBaseName + $logfileNumber + $logfileExtension)
        }

        # log mode, temp, and topP
        if ($Mode) {
            Write-LogMessage -Message "Mode: $mode" -LogFile $logfile
        }
        Write-LogMessage -Message "temperature=$Temperature, topP=$TopP" -LogFile $logfile

        # Call functions to execute API request and output results
        $headers = Get-Headers -ApiKeyVariable $script:API_AZURE_OPENAI_KEY -Secure

        # system prompt
        
        if (-not ($o1 -or $o3)) {
            if ($SystemPromptFileName) {
                $system_message = get-content -path $SystemPromptFileName -Encoding UTF8 -Raw 
            }
            else {
                if ($SystemPrompt) {
                    $system_message = $SystemPrompt
                }
                else {
                    #$system_message = Read-Host -Prompt "Enter the system prompt message"
                    $system_message = "You are a helpful, knowledgeable, and polite assistant. Your goal is to assist the user by providing accurate, concise, and informative responses to their queries. Remain neutral and avoid giving opinions unless explicitly asked. Provide explanations where necessary, but keep the responses simple and clear."
                }
            }
            # cleaning system prompt
            $system_message = [System.Text.RegularExpressions.Regex]::Replace($system_message, "[^\x00-\x7F]", "")        

            if ($VerbosePreference -eq "Continue") {
                Write-verbose (Write-PSAOAIMessage -content $system_message -stream "system" | Out-String)
            }
        }
        

        # user prompt message
        if ($OneTimeUserPrompt) {
            # cleaning user message
            $userMessage = Format-Message -Message $OneTimeUserPrompt
            Write-Verbose "OneTimeUserPrompt: $userMessage"
        }
        else {
            Write-Verbose "NO OneTimeUserPrompt: $userMessage"
            if (-not $userMessage) {
                $userMessage = Read-Host "Enter chat message (user)"
            }
            $userMessage = Format-Message -Message $userMessage
            Write-Verbose $userMessage
        }
        

        # Get the messages from the system and user
        if ($o1 -or $o3) {
            $messages = @()
            $messages += Get-PSAOAIMessageso1 -UserMessage $userMessage
        }
        else {
            $messages = Get-PSAOAIMessages -systemmessage $system_message -UserMessage $userMessage -JSONMode $JSONMode
        }

        # Write the messages to the verbose output
        Write-Verbose "Messages: $($messages | out-string)"

        # Get the URL for the chat
        $urlChat = Get-PSAOAIUrl -Endpoint $Endpoint -Deployment $Deployment -APIVersion $APIVersion -Mode chat

        # Write the URL to the verbose output
        Write-Verbose "urlChat: $urlChat"

        if (-not ($o1 -or $o3)) {
            # Write the system prompt to the log file
            Write-LogMessage -Message "System promp:`n======`n$system_message`n======`n" -LogFile $logfile
        }
        # Write the user message to the log file
        Write-LogMessage -Message "User message:`n======`n$userMessage`n======`n" -LogFile $logfile

        do {
            # Get the body of the message
            if ($o1 -or $o3) {
                $body = Get-PSAOAIChatBodyo1 -messages $messages -max_completion_tokens $MaxTokens
            }
            else {
                $body = Get-PSAOAIChatBody -messages $messages -temperature $parameters['Temperature'] -top_p $parameters['TopP'] -frequency_penalty $FrequencyPenalty -presence_penalty $PresencePenalty -user $User -n $N -stop $Stop -stream $Stream -MaxTokens $MaxTokens -JSONMode $JSONMode
            }

            # Convert the body to JSON
            $bodyJSON = ($body | ConvertTo-Json)
            
            # If not a simple response, display chat completion and other details
            if (-not $simpleresponse -and -not $userWasAsked) {
                Write-Host "[Chat completion]" -ForegroundColor Green
                if ($logfile) {
                    Write-Host "{Logfile:'${logfile}'} " -ForegroundColor Magenta
                }
                if ($o1) {
                    $o1DeailtsBanner = "{Mode: 'o1', max_completion_tokens: '$MaxTokens'} "
                } elseif ($o3) {
                    $o3DeailtsBanner = "{Mode: 'o3', max_completion_tokens: '$MaxTokens'} "
                }
                if ($SystemPromptFileName) {
                    if ($o1) {
                        Write-Host $o1DeailtsBanner -NoNewline -ForegroundColor Magenta
                    } elseif ($o3) {
                        Write-Host $o3DeailtsBanner -NoNewline -ForegroundColor Magenta
                    }
                    else {
                        Write-Host "{SysPFile:'$(Split-Path -Path $SystemPromptFileName -Leaf)', temp:'$($parameters['Temperature'])', top_p:'$($parameters['TopP'])', max_tokens:'${Maxtokens}', fp:'${FrequencyPenalty}', pp:'${PresencePenalty}', user:'${User}', n:'${N}', stop:'${Stop}', stream:'${Stream}'} " -NoNewline -ForegroundColor Magenta
                    }
                }
                else {
                    if ($o1) {
                        Write-Host $o1DeailtsBanner -NoNewline -ForegroundColor Magenta
                    } 
                    elseif ($o3) {
                        Write-Host $o3DeailtsBanner -NoNewline -ForegroundColor Magenta
                    }
                    else {
                        Write-Host "{SysPrompt, temp:'$($parameters['Temperature'])', top_p:'$($parameters['TopP'])', max_tokens:'${Maxtokens}', fp:'${FrequencyPenalty}', pp:'${PresencePenalty}', user:'${User}', n:'${N}', stop:'${Stop}', stream:'${Stream}'} " -NoNewline -ForegroundColor Magenta
                    }
                }
            }
           
            # Invoke the API request
            if ($Stream) {
                $response = Invoke-PSAOAIApiRequestStream -url $urlChat -headers $headers -bodyJSON $bodyJSON -Chat -timeout $TimeOut -logfile $logfile | out-string
                if ([string]::IsNullOrEmpty($response)) {
                    Write-Warning "Response is empty"
                    Write-LogMessage -Message "Response is empty" "WARNING" -LogFile $logfile
                    return
                }
                $assistant_response = $response
            }
            else {
                $response = Invoke-PSAOAIApiRequest -url $urlChat -headers $headers -bodyJSON $bodyJSON -timeout $TimeOut
                if ([string]::IsNullOrEmpty($($response.choices[0].message.content))) {
                    Write-Warning "Response is empty"
                    Write-LogMessage -Message "Response is empty" "WARNING" -LogFile $logfile
                    return
                }
                # Write the received job to verbose output
                Write-Verbose ("Received job output:`n$($response | ConvertTo-Json)" | Out-String)
                # Get the assistant response
                
                $assistant_response = $response.choices[0].message.content
            }

            #if (-not $o1) {
                # Add the assistant response to the messages                
                $messages += @{"role" = "assistant"; "content" = $assistant_response }
            #}
            #elseif ($o1) {
            #    $messages += @{"role" = "assistant"; "content" = $assistant_response }
            #}

            # If there is a one-time user prompt, process it
            if ($OneTimeUserPrompt) {
                Write-Verbose "OneTimeUserPrompt output with return"
                if (-not $simpleresponse -and (-not $Stream) -and (-not ($o1 -or $o3))) {
                    Write-Verbose "Show-FinishReason"
                    Write-Information -MessageData (Show-FinishReason -finishReason $response.choices.finish_reason | Out-String) -InformationAction Continue
                    Write-Verbose "Get-PSAOAIPromptFilterResults"
                    Write-Information -MessageData (Get-PSAOAIPromptFilterResults -response $response | Out-String) -InformationAction Continue
                    Write-Verbose "Show-Usage"
                    Write-Information -MessageData (Show-Usage -usage $response.usage | Out-String) -InformationAction Continue
                }
                Write-Verbose "Write-PSAOAIMessage - return"

                if (-not $Stream) {
                    # Get the response text
                    $responseText = (Write-PSAOAIMessage -content $assistant_response -stream "assistant" -simpleresponse:$simpleresponse | Out-String)
                }
                else {
                    $responseText = $response
                }
                # Write the one-time user prompt and response text to the log file
                Write-LogMessage -Message "OneTimeUserPrompt:`n======`n$OneTimeUserPrompt`n======`n" -LogFile $logfile
                Write-LogMessage -Message "ResponseText:`n======`n$responseText`n======`n" -LogFile $logfile
                Write-LogMessage -Message "Chat finished" -LogFile $logfile
                # Return the response text
                if (-not $Stream) {
                    return $responseText
                }
                else {
                    # The script returns a value when $Stream is true. 
                    # This means that in this situation, always save the value to a variable to avoid duplicating the response.
                    return $responseText
                }           
            }
            else {
                Write-Verbose "NO OneTimeUserPrompt"
                if (-not $Stream) {
                    # Show the response message
                    Write-PSAOAIMessage -content $assistant_response -stream "assistant" -simpleresponse:$simpleresponse
                }
            
                # Write the assistant response to the log file
                Write-LogMessage -Message "Assistant response:`n======`n$assistant_response`n======`n" -LogFile $logfile
                
                # Get the user message
                Write-LogMessage -Message "Waiting for user input" -LogFile $logfile
                write-host "`n >> Enter chat message ('Q'-exit): " -BackgroundColor Cyan -ForegroundColor DarkYellow -NoNewline
                $user_message = read-host
                $userWasAsked = $true
                if ($user_message -eq "Q") {
                    Write-Host "Exiting script as per user request."
                    Write-LogMessage -Message "Chat finished as per user request." -LogFile $logfile
                    return 
                }
                # Add the user message to the messages
                $messages += @{"role" = "user"; "content" = $user_message }

                write-verbose ("Elements in message array: "+$messages.Count | out-string)
                # Ensure the messages array consists of only the last 10 elements
                if ($messages.Count -gt 10 -and ($o1 -or $o3)) {
                    $messages = $messages[-10..-1]
                    
                }

                # Write the user response to the log file
                Write-LogMessage -Message "User input:`n======`n$user_message`n======`n" -LogFile $logfile
            }
            
        } while ($true)
    }
    catch {
        #Format-Error -ErrorVar $_
        #Show-Error -ErrorVar $_
        Write-LogMessage -Message"An error occurred: $_" -Level "ERROR" -LogFile $logfile
        Write-Error $_
        return
    }
    #endregion Main
}
