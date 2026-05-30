# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Maltex is a native macOS download manager built with SwiftUI, powered by the aria2 engine. It's a complete rewrite of Motrix with deep macOS integration including menu bar extras, Safari extension, and system appearance support.

**Tech Stack:**
- SwiftUI + Combine for UI
- aria2/aria2-next as download engine (bundled binaries)
- Aria2Kit for JSON-RPC communication
- XcodeGen for project generation
- Sparkle for auto-updates

## Build & Development

### Prerequisites
- macOS 14.0+
- Xcode 15.0+ with Swift 6.2
- XcodeGen: `brew install xcodegen`

### Build Commands

```bash
# Generate Xcode project (required after cloning or modifying project.yml)
xcodegen generate

# Open project
open Maltex.xcodeproj

# Run tests
xcodebuild test -scheme Maltex -destination 'platform=macOS'

# Run specific test
xcodebuild test -scheme Maltex -destination 'platform=macOS' -only-testing:MaltexTests/SettingsStoreTests/testDefaultValues

# Build release (via bundle script)
./bundle.sh arm64    # or x64
```

### Version Bumping

Version is defined in `project.yml`:
- `MARKETING_VERSION`: User-facing version (e.g., 1.1.5)
- `CURRENT_PROJECT_VERSION`: Build number (e.g., 1150)

Update both in all three targets (Maltex, Maltex Extension, MaltexTests).

### Release Process

1. Update `CHANGELOG.md` with new version section `## [X.Y.Z] - YYYY-MM-DD`
2. Commit and push changes
3. Push to `main` branch triggers GitHub Actions CI
4. CI automatically:
   - Extracts version from CHANGELOG.md
   - Builds Universal/x86_64/arm64 binaries
   - Creates DMG and ZIP packages
   - Publishes GitHub Release
   - Generates Sparkle appcast
   - Updates Homebrew cask

**Important:** CI only triggers on CHANGELOG.md changes or manual workflow_dispatch.

## Architecture

### Core Components

**EngineManager** (`Maltex/Core/EngineManager.swift`)
- Manages aria2/aria2-next process lifecycle
- Handles binary selection (bundled aria2, bundled aria2-next, command-line, custom)
- Builds command-line arguments based on SettingsStore
- **Auto-fallback mechanism**: If aria2-next fails (verification/launch/crash), automatically falls back to bundled aria2
- Writes logs to `~/Library/Application Support/Maltex/maltex.log`

**TaskStore** (`Maltex/Store/TaskStore.swift`)
- Central state manager for download tasks
- Communicates with aria2 via Aria2Kit JSON-RPC
- Polls engine every 1s for task updates
- Serializes addUri/addTorrent actions to avoid RPC flooding
- Handles connection state and error recovery

**SettingsStore** (`Maltex/Store/SettingsStore.swift`)
- Persists all user preferences via @AppStorage
- Includes aria2-next specific settings (proxy mode, log levels, torrent metadata)
- Settings are passed to EngineManager when starting/restarting engine

**HistoryStore** (`Maltex/Store/HistoryStore.swift`)
- Tracks completed/removed downloads
- Persists to JSON file in Application Support

### Engine Binary Selection

The app supports multiple aria2 sources (see `SettingsStore.Aria2BinarySource`):

1. **bundled**: Standard aria2c (in `extra/darwin/{arch}/engine/aria2c`)
2. **bundledAria2Next**: Experimental aria2-next with enhanced features (in `extra/darwin/{arch}/engine/aria2-next`)
3. **commandLine**: System-installed aria2c (Homebrew paths)
4. **custom**: User-specified path

**Aria2-Next Differences:**
- Uses `--torrent-metadata` instead of `--bt-save-metadata`
- Uses `--bt-force-encryption` instead of `--bt-require-crypto`
- Adds `--proxy-mode`, `--terminal-log-level`, `--file-log-level`, `--log-max-size`, `--log-max-files`
- Does NOT support `--bt-request-peer-speed-limit`, `--disable-upnp`

When aria2-next is selected, `EngineManager.buildArguments()` uses `isAria2Next` flag to conditionally include/exclude parameters.

### Data Flow

1. **App Launch**: `MaltexApp.swift` initializes TaskStore, SettingsStore, starts engine if `aria2StartOnLaunch` is enabled
2. **Engine Start**: EngineManager spawns aria2 process with arguments from SettingsStore
3. **RPC Connection**: TaskStore connects to `localhost:16800` (or configured host/port)
4. **Polling**: TaskStore calls `aria2.tellActive()`, `aria2.tellWaiting()`, `aria2.tellStopped()` every second
5. **UI Updates**: Published properties trigger SwiftUI view updates

### URL Handling

The app registers for:
- `maltex://` custom URL scheme
- `.torrent` file associations
- `magnet:` links

Handled in `MaltexApp.handleIncomingURL()` → `TaskStore.addUri()` or `TaskStore.addTorrent()`.

### Localization

All user-facing strings use `String(localized:)` with keys defined in `Maltex/Localizable.xcstrings`. Supports English and Simplified Chinese.

## Testing

Tests are in `MaltexTests/`:
- `DownloadTaskTests.swift`: Model equality and hashing
- `SettingsStoreTests.swift`: Default values and enum cases
- `FormattersTests.swift`: Byte/speed formatting

Run tests via Xcode or `xcodebuild test`.

## Troubleshooting

**Engine won't start:**
- Check logs: `~/Library/Application Support/Maltex/maltex.log` and `aria2.log`
- Kill stray processes: `pkill -9 aria2c`
- Clear app data: `rm -rf ~/Library/Application\ Support/Maltex`

**RPC connection fails:**
- Verify engine is running: `ps aux | grep aria2`
- Check RPC settings in Preferences → Aria2
- Ensure port 16800 is not blocked

**Aria2-next fallback:**
- If aria2-next fails verification/launch, check `maltex.log` for fallback messages
- The app automatically switches to bundled aria2 without user intervention

## Code Conventions

- **Swift Concurrency**: Use `@MainActor` for UI-bound classes (TaskStore, EngineManager)
- **Published Properties**: All UI state in stores uses `@Published`
- **Error Handling**: Log errors to app log file, surface critical errors via `TaskStore.shouldPresentEngineError`
- **RPC Calls**: Always handle both success and error cases in Aria2Kit `.response {}` closures
- **Settings Changes**: Restart engine via `EngineManager.restart(settings:)` to apply new configuration

## Important Files

- `project.yml`: XcodeGen project definition (modify this, not .xcodeproj)
- `CHANGELOG.md`: Version history (triggers CI when updated)
- `.github/workflows/release.yml`: CI/CD pipeline
- `bundle.sh`: Manual build script for local testing
- `extra/darwin/{arch}/engine/`: Bundled aria2 binaries (committed to repo)

## Safari Extension

Located in `MaltexExtension/`. Captures download links and sends them to the main app via XPC. Built as an app extension target.
