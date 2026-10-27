# PowerShell Azure OpenAI (PSAOAI) - release notes

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.7.0]

Publication: [PowerShell Gallery 0.7.0](https://www.powershellgallery.com/packages/PSAOAI/0.7.0), published by the user and verified live by the user/parent agent. Exact-version installation: `Install-Module -Name PSAOAI -RequiredVersion 0.7.0`. This documentation closeout does not claim installation or testing of a downloaded Gallery package.

### Added

- Explicit `Initialize-PSAOAIConfiguration` with validated endpoint and hidden API-key input, Process-only writes and secret-free status; opt-in Responses `-Interactive`. Default mode names missing configuration and directs setup without prompting. Mandatory Deployment/InputText behavior is preserved. Synthetic offline setup regression coverage; no native Windows persistence qualification.
- Separate `Invoke-PSAOAIResponse` text-only synchronous Azure Responses v1 MVP with explicit non-storing/non-streaming/non-background requests, full REST results and optional concatenated text.
- Dedicated UTF-8 JSON transport without jobs, retries, redirects or payload logging; sanitized terminating errors and explicit refusal/incomplete handling.
- Dependency-free offline PowerShell contract runner, real Python loopback HTTP scenarios, and isolated module-import/legacy export and URL checks.

### Qualification

- Offline tested on PowerShell 7.6.8 / WSL: runner self-test 2/0, full suite 61/0, isolated import with nine exports and four legacy URLs. Final validation made no provider calls or installations; CI remains unchanged. Manifest and runtime version remain 0.7.0. These are historical local qualification results, not Gallery-package acceptance.
- Separately approved live acceptance of the actual dot-sourced cmdlet verified configuration lookup, API-key authentication, HTTPS transport and parser on `gpt-6.1-sol`: output budget 512, `completed`, text `OK`, tokens 11 input / 5 output / 16 total, `store=false`. That historical dot-source test did not qualify ordinary module bootstrap, other models/regions/runtimes or full regression of older commands. The subsequent bounded import UX fix changes API-version setup and banner presentation only; PSGallery/TLS bootstrap and older transports remain unchanged.

Later user-reported acceptance: native Windows actual installed source exercised real Azure in both simple and full modes successfully (`completed`, `OK`, 16 total tokens, `store=false`). This does not qualify a downloaded Gallery package or Windows User/Machine persistence. Development is parked pending a reproducible defect or concrete caller need; any new work requires separate approval.

### Fixed

- Prevent the Responses HTTP/timeout error → parser ProtocolError cascade under default ErrorAction Continue. The public boundary stops the nested transport and preserves its sanitized record; Stop remains catchable. Fresh-process loopback 401/400/timeout tests cover Continue/Stop and full/text modes, one error and zero parser calls. 401 guidance checks matching resource/key, current key and enabled local API-key authentication without claiming a certain cause or exposing provider bodies. No new Azure/native Windows acceptance at that repair checkpoint; later source-install acceptance is recorded above.

- Import no longer calls interactive API-version setup or discovers/overwrites a configured version. Legacy command setup remains interactive when intentionally invoked without configuration. A concise latest-version-only manifest note is shown with the banner unless effective `PSAOAI_BANNER` is `0` (Process → User → Machine); `1` enables it. Five isolated import cases verify prompts/writes/discovery absent, configuration preserved, all exports and legacy URLs, and User suppression through a synthetic read seam. PSGallery/TLS bootstrap remains unchanged; ordinary network import and native Windows User persistence are not qualified.
- Additive `Get-PSAOAIEnv` fix included in 0.7.0: optional validated Process/User/Machine scope; all three scopes by default with duplicate names preserved as separate Name/Value/Scope/Info objects. API keys are fully masked as `****` without encryption assumptions; empty inventory emits information only. Synthetic scope regression runner: RED 0/9, GREEN 9/0; existing Responses suite 49/0 (no skips). Configuration lookup and Clear behavior remain unchanged.
- Responses transport rejects a singleton JSON array root rather than accidentally accepting its enumerated object; covered by a real loopback RED/GREEN regression.

## [0.6.5] - 2026.03.27

### Added

### Fix

### Changed

- Performed additional packaging cleanup for a cleaner release artifact.

## [0.6.4] - 2026.03.26

### Added

- Added `tools/diagnostics/Test-Gpt54DirectResponseMatrix.ps1` for direct `gpt-5.4` request/response diagnostics.

### Fix

- Improved WSL/Linux and Azure OpenAI compatibility for environment variable and API key handling.

### Changed

- Improved request/response diagnostics with saved request metadata plus success/error artifacts for easier debugging.
- Improved handling and troubleshooting for Azure-backed flows, including direct `gpt-5.4` diagnostics.

## [0.6.3] - 2025.04.18

### Added

- Added UTF-8 decoding for o1, o3 response stream.

### Fix

### Changed

- change Invoke-RestMethod to Invoke-WebRequest

## [0.6.2] - 2025.03.23

### Added

- Added support for a new optional parameter 'o3' (o3 models)

### Fix

- Chat: remove permanent verbose message.

### Changed

- Enhanced Get-PSAOAIEnv function to partially mask sensitive API keys.

## [0.6.1] - 2024.10.23

### Added

### Fix

- chat: [#7](https://github.com/voytas75/PSAOAI/issues/7).

### Changed

## [0.6.0] - 2024.10.16

### Added

- Chat: support o1 models ([#6](https://github.com/voytas75/PSAOAI/issues/6)).
- Chat: `o1` switch for o1 models.

### Fix

- [#5](https://github.com/voytas75/PSAOAI/issues/5).

### Changed

- Chat: remove `Parameter sets`.
- Completion: remove `Parameter sets`.

## [0.5.1] - 2024.10.05

### Added

- Added return image path for Dalle3.
- Chat: Default system prompt.

### Fix

### Changed

- Chat: Adjusted default values for Temperature and TopP.
- Chat: Updated Verbose display.

## [0.4.3] - 2024.07.21

### Added

### Fix

### Changed

- Chat: Restore value when stream is $true.

## [0.4.2] - 2024.07.21

### Added

### Fix

- Removed duplicate return value when stream is $true.

### Changed

## [0.4.1] - 2024.07.19

### Added

- Chat: json mode ([#1](https://github.com/voytas75/PSAOAI/issues/1)).

### Fix

### Changed

## [0.3.2] - 2024.07.10

### Added

### Fix

- Environment Variables

### Changed

- Project site url

## [0.3.1] - 2024.07.02

### Fix

- Minor fixes.

### Changed

- Chat: Enhanced mode,
- Chat: Simplified environment variable handling,
- Refactoring.

## [0.3.0] - 2024.06.19

### Added

- Timeout param,
- Chat: param `max_tokens`.

## [0.2.1] - 2024.06.03

### Fix

- Chat: error returned as response,
- Chat: response.

### Changed

- Set default stream to TRUE,
- Chat: verification of response when not stream.

## [0.2.0] - 2024.05.30

### Added

- Logfolder parameter to Completion - [#3](https://github.com/voytas75/AzureOpenAI-PowerShell/issues/3),
- Completion: Added timestamp to log filename,
- Completion, Chat: Streaming response,
- Ready for core edition,
- Streaming response: timeout.

### Fix

- Completion, Chat: logfileDirectory.

### Changed

- Chat: logfilename suffix - [#4](https://github.com/voytas75/AzureOpenAI-PowerShell/issues/4)

## [0.1.0] - 2024.04.26

### Added

- Posiotional parameters,
- [#1](https://github.com/voytas75/AzureOpenAI-PowerShell/issues/1),
- Error handling: [#2](https://github.com/voytas75/AzureOpenAI-PowerShell/issues/2).

### Fix

- Passing temperature, topp, and mode parameters.

## [0.0.2] - 2024.04.17

### Added

- Function to retrieve the API versions from the Azure OpenAI GitHub repository.
- Function to clear the Azure OpenAI API environment variables.

### Changed

- Modified API key handling with security.
- Make functions as stand-alone files.

### Fix

- Secure API KEY.

## [0.0.1] - 2024.04.07

### Added

- Initiated the module for the first time.
