---
slug: architecture
title: System architecture
role: system architecture
updated: "2026-08-31T14:37:33"
---

# System architecture

```mermaid
graph TD
    UI[SwiftUI Views: Main Window, Menu Bar, Settings] --> Stores[Observable Stores: TaskStore, SettingsStore, HistoryStore]
    Stores --> RPC[Aria2Kit JSON-RPC Client]
    RPC -->|HTTP / localhost:16800| Engine[aria2 Process: aria2c / aria2-next / aria2-rust]
    EngineManager[Core / EngineManager] -->|Process Lifecycle & Auto-Fallback| Engine
    SafariExt[Safari Web Extension: Maltex Extension.appex] -->|Link Capture| UI
    Sparkle[Sparkle 2.x Updater] -->|Dual-Arch Appcast| AppUpdate[App Updates]
```

## Layer Responsibilities

1. **`Maltex/Views/`**: SwiftUI declarative interface (task queues, sidebar with status indicators, inspector panels, settings tabs, menu bar extra popup, `WhatsNewSheetView`).
2. **`Maltex/Store/`**:
   - `TaskStore`: Central task manager, polls `tellActive`, `tellWaiting`, `tellStopped` every 1s, queues RPC mutations to prevent flooding.
   - `SettingsStore`: Persists preferences via `@AppStorage`, manages tracker URLs and engine selections (`.bundled`, `.bundledAria2Next`, `.bundledAria2Rust`, `.commandLine`, `.custom`).
   - `HistoryStore`: Persists completed/removed tasks to Application Support JSON.
3. **`Maltex/Core/`**:
   - `EngineManager`: Process lifecycle owner. Constructs 40+ CLI arguments, resolves architecture-specific binary URLs, executes pre-launch `--version` verification, and manages triple automatic fallback to standard bundled aria2 on failure.
4. **`Maltex/Core/Integrations/`**: Third-party framework adapters (Sparkle updater controllers).
5. **`MaltexExtension/`**: Safari Web Extension target capturing `thunder://`, `ed2k://`, `magnet:`, `.torrent`, and HTTP download links.
