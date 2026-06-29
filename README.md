# Sonar

Sonar is a HarmonyOS music client compatible with SonicAPI/Subsonic servers, designed for self-hosted services such as Navidrome.

## Highlights

- SonicAPI/Subsonic-compatible authentication and API requests.
- Works with self-hosted servers like Navidrome.
- Supports remote server URL and optional LAN/local URL switching.
- Album library browsing, album detail view, and basic search flow.
- Built with ArkTS + ArkUI (Stage model).

## Tech Stack

- HarmonyOS `6.1.1`
- ArkTS / ArkUI
- DevEco Studio + Hvigor build system

## Getting Started

### 1) Prerequisites

- DevEco Studio (with HarmonyOS SDK installed)
- A SonicAPI-compatible server account (for example Navidrome)
- Local signing materials for HarmonyOS app build

### 2) Open Project

Open this folder in DevEco Studio and let dependencies sync.

### 3) Configure Signing

The repository uses placeholder values in `build-profile.json5`.
Replace these fields with your local signing files and passwords:

- `certpath`
- `profile`
- `storeFile`
- `keyPassword`
- `storePassword`

Recommended: keep your actual certificate files outside the repository or under a local ignored path.

### 4) Build and Run

Use DevEco Studio to run on emulator/device, or run the equivalent Hvigor tasks from terminal.

## Project Structure

- `AppScope/`: app-level metadata/resources
- `sonar/src/main/ets/sonar/`: main app source code
- `sonar/src/main/ets/sonar/api/`: SonicAPI/Subsonic client and types
- `sonar/src/main/ets/sonar/pages/`: UI pages (login/library/album detail)
- `sonar/src/main/ets/sonar/auth/`: credential/session persistence

## Open Source Notes

- Build artifacts, local dependencies, and IDE cache files are excluded via `.gitignore`.
- Sensitive local signing values have been replaced by placeholders.
- Before publishing, consider adding a license file (for example `MIT`).
