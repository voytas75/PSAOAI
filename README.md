# PowerShell Azure OpenAI (PSAOAI) Module

[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![PowerShell 7](https://img.shields.io/badge/PowerShell-7-2C5AA0?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/PSAOAI)](https://www.powershellgallery.com/packages/PSAOAI)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/PSAOAI)](https://www.powershellgallery.com/packages/PSAOAI)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/b299e2b2499942589ee6fe26c972fbb9)](https://app.codacy.com/gh/voytas75/PSAOAI/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![Module Version 0.7.0](https://img.shields.io/badge/module-0.7.0-blue.svg)](https://github.com/voytas75/PSAOAI/blob/master/docs/ReleaseNotes.md)

![PSAOAI](https://github.com/voytas75/PSAOAI/blob/master/images/PSAOAI128.png?raw=true "PowerShell Azure OpenAI (PSAOAI) Module")

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A6KYBUS)

PSAOAI is a PowerShell module for working with Azure OpenAI from scripts, consoles, and automation workflows.

It gives you a PowerShell-native surface for chat completions, embeddings, image generation, and environment handling without forcing you to drop into raw REST calls every time.

It is most useful when you want a practical PowerShell wrapper around Azure OpenAI that is easy to install from PowerShell Gallery, script, and reuse across automation tasks.

![PSAOAI](https://github.com/voytas75/PSAOAI/blob/master/images/PSAOAI.png?raw=true "PowerShell Azure OpenAI (PSAOAI) Module")

## Who this is for

PSAOAI is a good fit for:
- PowerShell users who want a reusable Azure OpenAI module instead of ad-hoc REST snippets
- automation engineers who want repeatable prompt, embedding, or image-generation workflows
- people building higher-level tools on top of a PowerShell-native OpenAI integration layer

PSAOAI is not the best fit for:
- users who want a provider-agnostic framework first
- people expecting a full desktop product rather than a scriptable module layer
- cases where raw API experimentation is preferred over a PowerShell command surface

## Quick start

### 1. Install the module

```powershell
Install-Module -Name PSAOAI
Import-Module -Name PSAOAI
```

### 2. See what the module exports

```powershell
Get-Command -Module PSAOAI
```

### 3. Configure Azure OpenAI

Set the environment values needed by your Azure OpenAI deployment:

- `PSAOAI_API_AZURE_OPENAI_ENDPOINT`
- `PSAOAI_API_AZURE_OPENAI_APIVERSION`
- `PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT`
- `PSAOAI_API_AZURE_OPENAI_KEY`

### 4. Run a simple chat completion

```powershell
"Explain Azure Logic App IF conditions in simple terms." |
  Invoke-PSAOAIChatCompletion -Deployment "your_deployment" -SimpleResponse -Stream $false
```

## Responses API (0.7.0)

`Invoke-PSAOAIResponse` is a separate synchronous text command; it does not change Chat Completions or translate results to `choices[]`. This source-tree addition is not yet a PowerShell Gallery release. Offline qualification was performed on PowerShell 7.6.8 (WSL); Windows PowerShell 5.1 and other runtimes are not qualified for this command.

```powershell
Invoke-PSAOAIResponse -Endpoint 'https://RESOURCE.openai.azure.com' `
  -Deployment 'DEPLOYMENT-NAME' -InputText 'Odpowiedz krótko.' `
  -Instructions 'Use plain text.' -MaxOutputTokens 512 -SimpleResponse
```

Use the existing `PSAOAI_API_AZURE_OPENAI_KEY` configuration. Endpoint can fall back to `PSAOAI_API_AZURE_OPENAI_ENDPOINT`; an explicit endpoint takes precedence. Deployment is always explicit and maps to JSON `model`. Only HTTPS resource roots or `/openai/v1` bases are accepted; the URL is `/openai/v1/responses` without a dated API version. Missing configuration fails without a prompt or persistent write. Import itself retains the module's existing update check/configuration bootstrap effects.

The default result is the full REST object, including unknown fields, `usage`, `output` and `incomplete_details`. `-SimpleResponse` concatenates all `output_text` blocks in order without a separator. Refusals produce a warning in full mode and a terminating `PSAOAI.Response.Refused` in text mode. Incomplete results warn; text mode returns available partial text, otherwise `PSAOAI.Response.NoText`. Failed/error-bearing results terminate with `PSAOAI.Response.Failed`; malformed results use `PSAOAI.Response.ProtocolError`. HTTP failures and timeouts use `PSAOAI.Response.HttpError` and `PSAOAI.Response.Timeout` with sanitized diagnostics.

Requests explicitly set `store=false`, `stream=false`, and `background=false`; `store=false` is not a guarantee of zero service-side retention. Optional fields are sent only when supplied; timeout defaults to 60 seconds. The new transport does not log payloads, retry POSTs, follow redirects or use background jobs. It currently bypasses system proxies; proxy-dependent environments are not qualified. Tools, multimodal input, conversation state, SSE, Entra ID, reasoning controls and temperature/top_p are outside this MVP.

Offline checks use synthetic data and real loopback HTTP, not Azure:

```powershell
pwsh -NoLogo -NoProfile -File ./tests/Test-ResponsesApi.ps1 -SelfTest
pwsh -NoLogo -NoProfile -File ./tests/Test-ResponsesApi.ps1
```

Python 3 is optional and used only for loopback HTTP tests, not for the module itself. The runner detects `python3` or `python` and verifies Python 3; if unavailable, it explicitly skips the 11 loopback tests and runs the remaining checks. Use `-SkipLoopback` to skip them deliberately. A run with skips does not qualify real HTTP transport. Pester is not required. Import verification uses a disposable module copy with a configuration-write stub plus actual exercised PSGallery/REST stubs in a child process. This proves the isolated import and legacy exports/URL builders, not that ordinary module import is side-effect-free. Separately, an approved live acceptance exercised the actual dot-sourced cmdlet, real configuration lookup, API-key authentication, HTTPS transport and parser on `gpt-6.1-sol`: budget 512, status `completed`, text `OK`, usage 11 input + 5 output = 16 total tokens, `store=false`. Ordinary module bootstrap was bypassed and is not live-qualified; other models/regions and runtimes remain unqualified. No further Azure calls are authorized. The 0.7.0 source release is ready for Gallery publication; Gallery publication remains pending; CI is unchanged. The installation command above retrieves the published Gallery version, not version 0.7.0. See [the source-tree execution plan](https://github.com/voytas75/PSAOAI/blob/master/docs/ResponsesApiPlan.md) (not included in the runtime package). Test commands above run from the source checkout; tests are not packaged.

## Supported scenarios

- chat completions for scripted or interactive use
- embeddings for search, similarity, or downstream automation
- image generation through DALL-E 3
- environment and key handling for repeated local usage
- logging and reusable PowerShell-native integration in other tools

## Known limitations

- The module is primarily positioned around **Azure OpenAI**; it is not a broad multi-provider abstraction layer.
- Real usability depends on correct local environment configuration and valid deployment settings.
- The smoothest first-run path is a single verified Azure OpenAI deployment, not a complex multi-model setup.
- This repo currently presents itself more as a practical module than as a heavily packaged developer platform.

## Core capabilities

- **Chat completions** for interactive or scripted Azure OpenAI calls, including `o1` and `o3`-style usage.
- **Embeddings** for similarity, retrieval, and downstream automation workflows.
- **Image generation** through DALL-E 3.
- **Secure key and environment handling** for repeated local usage.
- **Response logging** for debugging, auditing, and operational review.
- **PowerShell-native commands** that are easier to script and reuse than raw REST calls.

## Usage examples

### Responses API (0.7.0)

Return plain text using an explicit Azure deployment (not a pipeline input):

```powershell
$text = Invoke-PSAOAIResponse -Endpoint 'https://RESOURCE.openai.azure.com' `
  -Deployment 'gpt-6.1-sol' -InputText 'Explain Azure Logic Apps briefly.' `
  -Instructions 'Use plain text.' -MaxOutputTokens 512 -SimpleResponse
$text
```

Omit `-SimpleResponse` to retain the full REST result, including status and token usage:

```powershell
$response = Invoke-PSAOAIResponse -Endpoint 'https://RESOURCE.openai.azure.com' `
  -Deployment 'gpt-6.1-sol' -InputText 'Reply with exactly: OK' -MaxOutputTokens 512
$response.status
$response.usage
```

The deployment must exist in your Azure resource. Both examples use the existing `PSAOAI_API_AZURE_OPENAI_KEY` configuration and send `store=false`, `stream=false`, and `background=false`. See [Responses API](#responses-api-070) for configuration, errors and qualification limits.

### Chat completion

- **Basic `o1`-style usage**

  ```powershell
  "<describe reasoning problem>" | Invoke-PSAOAIChatCompletion -Deployment "model_o1" -o1
  ```

- **Structured non-streaming example**

  ```powershell
  "AZURE Logic App 'IF' element" | Invoke-PSAOAIChatCompletion -APIVersion "2024-05-01-preview" -Endpoint 
  "https://example.openai.azure.com" -Deployment "example_model_gpt35_!" -User "BobbyK" -Temperature 0.2 -TopP 0.7 
  -FrequencyPenalty 0 -PresencePenalty 0 -simpleresponse -SystemPrompt "Explain to me" -Stream $false -JSONMode
  ```

- **Capture a streamed response into a variable**

  ```powershell
  $resule = "AZURE Logic App 'IF' element" | Invoke-PSAOAIChatCompletion -APIVersion "2024-05-01-preview" -Endpoint 
  "https://example.openai.azure.com" -Deployment "example_model_gpt35_!" -User "BobbyK" -Temperature 0.2 -TopP 0.7 
  -FrequencyPenalty 0 -PresencePenalty 0 -simpleresponse -SystemPrompt "Explain to me" -Stream $true
  ```

- **`o3`-style usage**

  ```powershell
  Invoke-PSAOAIChatCompletion -Deployment "model_o3" -o3 -usermessage "Explain to me: $(Get-Content <plain_text_file_path> | out-string) `nReturn as Markdown format" -OneTimeUserPrompt
  ```

### Completion

```powershell
Invoke-PSAOAIcompletion -usermessage "explain winform" -Deployment "gpt45" -User "BobbyK" -simpleresponse -Stream $false
```

### Image generation

```powershell
Invoke-PSAOAIDalle3 -Prompt "A finely detailed, broken marble figure head half-submerged in sandy terrain. The scene is 
bathed in the illuminating glow of daylight. The artistic style of the image evokes the feel of Polish romanticism, 
characterized by a realistic approach with an underlying emotional dimension and emphasis on symbolic compositions often seen 
in Malczewski's works who was active before 1912. Please note, the marble figure head should be of no particular person, just 
a generic, anonymous sculpture." -quality hd 
```

### Embeddings

```powershell
$response = "Hello, World!" | Invoke-PSAOAIEmbedding -User "Gemini" -Verbose -Deployment "gpt-45" -simpleresponse
$response
```

## Default log and data folder

If specific paths are not provided, PSAOAI uses:

- `<User's document folder>/PSAOAI/`

That folder is used for logs and module data and is created automatically when the module is imported.

## Versioning

We use [SemVer](http://semver.org/) for versioning.

## Contributing

Contributions, issue reports, and improvement suggestions are welcome.

If you want to extend the module, start by reviewing the exported commands, current release notes, and the existing PowerShell module layout in this repo.

### License

PSAOAI is released under the [MIT License](https://github.com/voytas75/PSAOAI/blob/master/LICENSE).

## Contact

If you have questions, bug reports, or improvement ideas, use [GitHub Issues](https://github.com/voytas75/PSAOAI/issues).
