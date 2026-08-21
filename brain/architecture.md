---
slug: architecture
title: System architecture
role: system architecture
updated: "2026-08-21T06:38:35"
---

# System architecture

```mermaid
graph TD
    App[Maltex App] --> Views[SwiftUI Queue & Inspector Views]
    Views --> Engine[Download Engine & Scheduler]
    Engine --> Tasks[DownloadTask Workers]
    Tasks --> Net[URLSession Async Stream / HTTP Range]
```
