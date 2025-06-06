# PowerShell Azure OpenAI (PSAOAI) - release notes

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.6.4] - 2025.04.18

### Added

### Fix

### Changed

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
