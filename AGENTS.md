# AGENTS.md

This file provides operational guidance to AI coding agents (Antigravity, Cursor, Codex, OpenCode, Pi, etc.) working in this repository.

## 1. Project Overview

Maltex is a native macOS download manager built with SwiftUI, powered by the aria2 engine.
- **Architectures**: Dual-track model:
  - `1.2.x` (`main` branch): Dual-architecture (Apple Silicon `arm64` & Intel `x86_64`)
  - `1.3.x` (`feature/aria2-rust` branch): Apple Silicon (`arm64`) exclusive
- **Tech Stack**: SwiftUI + Combine, Aria2Kit (JSON-RPC), Sparkle 2.x (Auto-updates), XcodeGen (`project.yml`).

## 2. Build & Test Commands

```bash
# 1. Regenerate Xcode project (REQUIRED after editing project.yml)
xcodegen generate

# 2. Build Debug Application
xcodebuild -project Maltex.xcodeproj -scheme Maltex -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

# 3. Run Unit Tests (23+ tests)
xcodebuild -project Maltex.xcodeproj -scheme Maltex -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test

# 4. Run Specific Test Case
xcodebuild -project Maltex.xcodeproj -scheme Maltex -configuration Debug \
  -destination 'platform=macOS' -only-testing:MaltexTests/SettingsStoreTests/testDefaultValues test

# 5. Local Release Packaging
./bundle.sh arm64    # or ./bundle.sh x86_64 on 1.2.x
```

## 3. Architecture & Core Guidelines

- **Stores (`Maltex/Store/`)**:
  - `TaskStore`: Central download task manager, polls aria2 JSON-RPC every 1s, serialized action queues.
  - `SettingsStore`: Persists preferences via `@AppStorage`, manages tracker servers and engine source enum (`Aria2BinarySource`).
  - `HistoryStore`: Persists completed/removed tasks to JSON.
- **Engine Management (`Maltex/Core/EngineManager.swift`)**:
  - Owns aria2 process lifecycle (`aria2c`, `aria2-next`, and `aria2-rust` on 1.3.x).
  - Pre-flight binary verification (`--version` validation).
  - **Triple Auto-Fallback**: Automatically falls back to standard bundled aria2 on verification failure, launch failure, or immediate exit/crash.
- **Strict Concurrency**: Swift 6 standard. UI-bound managers (`TaskStore`, `EngineManager`) MUST be annotated with `@MainActor`.
- **Zero Hardcoded Strings**: All user-facing strings MUST use `String(localized:)` or `LocalizedStringKey` with keys registered in `Maltex/Localizable.xcstrings` (supporting English and Simplified Chinese).
- **Single Window Scene**: Always maintain single-instance `Window` structure in `MaltexApp.swift` to prevent duplicate windows when opening magnet/URLs.

<!-- BEGIN brain.md -->
## Project Brain

This project keeps a **Project Brain**: a persistent memory layer of its durable decisions, requirements, and constraints. Read `./BRAIN.md` for the full read/write contract.

Maintain the brain as part of normal coding work — not as a separate task. While discussing or implementing features:
- **Start of a task:** load relevant context with the `brain` CLI (`list-pages`, `read-page`, `read-root`). Prefer a narrow read over scanning everything.
- **When a decision, requirement, constraint, or durable insight settles** (in chat or while coding): capture it immediately via the `brain` CLI. Do not wait to be asked and do not batch it for later.
- **Pure implementation with no new decision:** do not write to the brain.
- **When overturning a prior conclusion:** update the page (`update-truth` and/or `append-timeline` with `kind: reversal`, or `archive-page`).
- Only store what will still matter in six months and is hard to reconstruct from the code alone.
- All reads and writes go through the `brain` CLI — never hand-edit brain files.

The brain skills (`brain-setup`, `brain-page`, `brain-ingest`, `brain-bootstrap`) are installed in your global skills directory. Prefer `brain init` to scaffold a new project.
<!-- END brain.md -->
