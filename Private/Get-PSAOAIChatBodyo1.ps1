# Function to generate the body for the API request
function Get-PSAOAIChatBodyo1 {
    <#
    .SYNOPSIS
    Constructs the body for the API request.
    
    .DESCRIPTION
    This function builds the body for the API request. It includes parameters such as messages, temperature, frequency_penalty, presence_penalty, top_p, stop, stream, and user.
    
    .PARAMETER messages
    An array of messages to be included in the API request. This parameter is mandatory.
    
    .PARAMETER temperature
    The temperature parameter for the API request, influencing the randomness of the chatbot's responses. This parameter is mandatory.
    
    .PARAMETER n
    The number of messages to generate for the API request. This parameter is mandatory.
    
    .PARAMETER frequency_penalty
    The frequency penalty parameter for the API request, controlling how much the model should avoid using frequent tokens. This parameter is mandatory.
    
    .PARAMETER presence_penalty
    The presence penalty parameter for the API request, controlling how much the model should favor tokens that are already present. This parameter is mandatory.
    
    .PARAMETER top_p
    The top-p parameter for the API request, controlling the nucleus sampling, a method of random sampling in the model. This parameter is mandatory.
    
    .PARAMETER stop
    The stop parameter for the API request, defining any tokens that should signal the end of a text generation.
    
    .PARAMETER stream
    The stream parameter for the API request, indicating whether the API should return intermediate results. This parameter is mandatory.
    
    .PARAMETER user
    The user parameter for the API request, representing the user initiating the request.
    
    .EXAMPLE
    Get-Body -messages $messages -temperature 0.5 -n 1 -frequency_penalty 0 -presence_penalty 0 -top_p 1 -stop null -stream $false -user "JohnDoe"
    
    .OUTPUTS
    Hashtable of parameters for the API request.

    .LINK
    https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models?tabs=python-secure#o1-preview-and-o1-mini-models-limited-access

    .NOTES
        Author: Wojciech Napierala
        Date: 2024-04

    #>    
    param(
        [Parameter(Mandatory = $true)]
        [array]$messages, # An array of messages to be included in the API request

        [Alias('max_completion_tokens')]
        [Parameter(Mandatory = $false)]
        [int]$MaxTokens # max_completion_tokens        
    )
    
    # Construct and return the body for the API request
    return @{
        'messages'              = $messages
        'max_completion_tokens' = $MaxTokens
    }
}
