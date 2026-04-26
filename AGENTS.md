# Agent Instructions for Maltex

## Project Overview

Maltex is a native macOS download manager built with SwiftUI and powered by an embedded `aria2c` engine. It includes:

- A main macOS app target: `Maltex`.
- A Safari Web Extension target: `Maltex Extension`.
- Unit tests in `MaltexTests`.
- Xcode project generation through XcodeGen.
- Sparkle 2.9.0 app update support.

The app focuses on native macOS behavior, reliable download task management, aria2 RPC integration, tracker management, Safari integration, localization, and Sparkle-compatible releases.

## Required Commands

Use these commands from the repository root unless the task states otherwise.

```bash
xcodegen generate
```

```bash
xcodebuild -project Maltex.xcodeproj -scheme Maltex -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

For package-level checks when appropriate:

```bash
swift test
```

Before handing off code changes, regenerate the Xcode project when `project.yml`, targets, packages, resources, build settings, versions, or file membership may be affected.

## Repository Layout

- `Maltex/`: Main macOS app source.
- `Maltex/Core/`: Engine, update, service, and integration logic.
- `Maltex/Core/Integrations/`: Third-party or platform integrations such as Sparkle.
- `Maltex/Models/`: Domain models such as download tasks and tracker source groups.
- `Maltex/Store/`: Observable state stores and persistence-facing state management.
- `Maltex/Views/`: SwiftUI screens, panels, dialogs, and menu bar UI.
- `Maltex/Utils/`: Shared formatting and utility code.
- `Maltex/Resources/`: Bundled app resources.
- `MaltexExtension/`: Safari Web Extension source and resources.
- `MaltexTests/`: Unit tests.
- `extra/darwin/*/engine/`: Bundled aria2 binaries and config files.
- `.github/workflows/release.yml`: Release, packaging, Sparkle appcast, and GitHub release workflow.
- `project.yml`: Source of truth for Xcode targets, dependencies, versions, and build settings.
- `CHANGELOG.md`: Source of truth for release notes.

Place new code by responsibility first, then by platform convention. Do not multiply entities, stores, managers, services, or wrappers unless the new boundary is necessary and clearly reduces complexity.

## Swift and Architecture Rules

- Swift version must stay at 6.0 or higher. The current project uses Swift 6.2.
- Prefer SwiftUI and native macOS APIs.
- Keep UI code in `Views`, app state in `Store`, domain data in `Models`, and engine/service logic in `Core`.
- Do not add legacy fallback paths.
- Prefer existing APIs and established project abstractions before creating new interfaces.
- Carefully verify third-party API behavior before changing service integrations.
- Keep `aria2` RPC handling compatible with the actual payloads returned by aria2 and Aria2Kit.
- Avoid user-specific absolute paths. Use app container, bundle resources, or repository-relative development paths as appropriate.
- Do not add broad abstractions for one-off behavior.
- Keep main-actor and concurrency boundaries explicit. Avoid introducing data races or unsafe cross-actor state unless there is a documented reason.

## Localization Rules

- Hard-coded user-facing string literals are not allowed.
- Localizable content must use `Maltex/Localizable.xcstrings` or the appropriate string catalog.
- Info.plist-facing localized content belongs in `Maltex/InfoPlist.xcstrings` when applicable.
- Xcode automatic string catalog behavior is enabled; preserve this workflow.
- When adding or changing UI text, update both English and Simplified Chinese localizations.
- Logs, internal debug prefixes, identifiers, RPC method names, file names, and protocol constants may remain non-localized when they are not user-facing.

## UI Rules

- Match the existing native macOS SwiftUI style.
- Keep screens practical and information-dense for download management workflows.
- Avoid decorative redesigns unless the task explicitly asks for visual redesign.
- Prefer standard controls, menus, alerts, sheets, and platform behaviors.
- Ensure text fits in compact window sizes and in both English and Chinese.
- Settings UI should remain stable in size and avoid layout jitter.

## Engine and Download Rules

- `EngineManager` owns the `aria2c` process lifecycle.
- `TaskStore` owns task polling, task mutations, task merge behavior, and RPC-facing task state.
- Do not start extra `aria2c` processes without a clear lifecycle plan.
- Preserve reliable session handling and app support paths under `~/Library/Application Support/Maltex`.
- Keep app logs and engine logs separated.
- When changing engine launch arguments, verify actual aria2 support and avoid breaking HTTP, FTP, BitTorrent, magnet, tracker, proxy, and session behavior.
- Keep architecture-specific bundled engines under `extra/darwin/arm64/engine` and `extra/darwin/x64/engine`.

## Safari Extension Rules

- Keep the Safari Web Extension target aligned with the main app where versions and bundle relationships matter.
- Extension source belongs under `MaltexExtension`.
- Do not duplicate app logic inside the extension unless the extension genuinely needs isolated behavior.

## Version and Release Rules

- `project.yml` is the source of truth for app and extension versions.
- When updating the app version, update both the main app and Safari extension build settings.
- When updating the software version, also update `CHANGELOG.md`.
- `CHANGELOG.md` release entries must include English first, then a separator line, then Chinese.
- The changelog format must remain compatible with the Sparkle 2.9.0 release notes extraction used by the workflow.
- Use the existing style:
  - `## [version] - YYYY-MM-DD`
  - English sections first.
  - `---`
  - `### Chinese`
  - Chinese sections after that.
- Do not leave temporary release-note files, generated `.log` files, or generated `.txt` files in the repository after finishing a task.

## GitHub Actions and Sparkle Rules

- Be extremely careful with `.github/workflows/release.yml`.
- Do not modify working version extraction or changelog extraction logic unless the user explicitly asks for that exact workflow change.
- The Sparkle 2.x release workflow relies on:
  - Cleaning the private key with `tr -dc 'A-Za-z0-9+/='`.
  - Setting `DYLD_FRAMEWORK_PATH` to the Sparkle tools directory.
  - Signing via stdin using `echo "$KEY" | generate_appcast --ed-key-file -`.
- Preserve generation of English and Simplified Chinese release note assets.
- Preserve Sparkle appcast release note links for `en` and `zh-Hans`.

## Bundle Identifier Rules

- New bundle identifiers must follow `com.steveshi.appname`.
- Do not casually rename existing bundle identifiers as part of unrelated changes.
- If a bundle identifier migration is requested, update all affected app, extension, entitlement, signing, release, and documentation references together.

## Testing and Verification

After code changes:

1. Run `xcodegen generate` if project generation may be affected.
2. Build the macOS app with `xcodebuild`.
3. Run focused tests when model, formatter, store, or service behavior changes.
4. For engine behavior, verify process startup, RPC connectivity, and relevant logs when feasible.
5. For localization changes, verify both English and Simplified Chinese strings are present.

If a command cannot be run, state clearly what was skipped and why.

## Temporary Files

- Clean up temporary `*.log` and `*.txt` files created during the task.
- Do not commit generated scratch output.
- Avoid leaving derived diagnostics in the repository root.

## Communication

- Communicate with the user in Chinese.
- Be concise but specific about files changed and verification performed.
- Prefer directly fixing and validating issues over only describing commands.
