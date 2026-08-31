---
slug: stack
title: Tech stack
role: tech-stack choices
updated: "2026-08-31T14:37:36"
---

# Tech stack

| Domain | Technology | Details & Rationale |
| :--- | :--- | :--- |
| **Language & Concurrency** | Swift 6.0+ (Swift 6.2) | Strict concurrency, `@MainActor` for UI-bound stores, modern async/await |
| **UI Framework** | SwiftUI + Combine | Native macOS controls, reactive state binding via `@Published` and `@AppStorage` |
| **Download Engine (C++)** | `aria2c` v1.37.0 (patched) | Uncapped `--max-connection-per-server` (1-*), HTTP/HTTPS, FTP, SFTP, BitTorrent, Metalink |
| **Download Engine (C++ Ext)** | `aria2-next` v2.6.4 | Realigned to v2.1.4 baseline + `--detach-share-only`, ED2K, native `thunder://` |
| **Download Engine (Rust)** | `aria2-rust` v0.3.4 (1.3.x track) | Memory-safe async Tokio-based Rust rewrite, JSON-RPC compatible |
| **RPC Client** | `Aria2Kit` v1.0.7 (Alamofire 5.12) | JSON-RPC 2.0 client communicating over HTTP localhost |
| **Project Generation** | XcodeGen (`project.yml`) | Declarative Xcode project definition, single source of truth |
| **Auto-Updates** | Sparkle 2.9.0 | Ed25519-signed dual-architecture Appcast distribution |
| **Extension** | Safari Web Extension (XPC) | Native browser link routing and URL interception |
