# Maltex

<p align="center">
  <img src="Maltex/Assets.xcassets/AppIcon.appiconset/icon.png" width="128" height="128" alt="Maltex Logo">
  <br>
  <b>基于 SwiftUI 构建的强大原生 macOS 下载工具。</b>
</p>

Maltex 是广受欢迎的 [Motrix](https://motrix.app/zh-CN) 下载管理器的原生重构版本，专为 macOS 生态系统设计。通过充分利用 SwiftUI 的性能优势和 `aria2` 引擎的稳定性，Maltex 为您提供更快速、更高效且深度集成的下载体验。

[English](./README.md) | [简体中文]

---

## 🚀 核心特性

- **纯原生 UI**: 完全基于 SwiftUI 构建，交互流畅，完美契合 macOS 系统审美。
- **全协议支持**: 轻松处理 HTTP、FTP、BitTorrent、磁力链接 (Magnet) 等多种协议。
- **卓越性能**: 内置深度优化的 `aria2` 核心，在保证极速下载的同时，维持极低的内存占用。
- **智能引擎管理**: 自动管理下载引擎的生命周期，开箱即用，无需繁琐配置。
- **深度系统集成**:
  - **菜单栏组件**: 实时监控下载/上传速度，通过菜单栏快速管理任务。
  - **外观适配**: 完美支持系统深色/浅色模式及强调色 (Accent Color)。
  - **Safari 扩展**: 内置 Safari 浏览器扩展，实现无缝网页下载接管。
- **原生适配 Apple Silicon**: 完美支持 M 系列及 Intel 芯片的 Mac。

## 📦 安装与开发

Maltex 目前处于活跃开发阶段，您可以从源码构建以体验最新功能。

### Homebrew
可以通过 Homebrew tap 安装：
```bash
brew tap SteveShi/tap
brew install --cask maltex
```

### 环境要求
- macOS 14.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### 构建步骤
1. **克隆仓库**:
   ```bash
   git clone https://github.com/SteveShi/Maltex.git
   cd Maltex
   ```
2. **生成 Xcode 工程**:
   ```bash
   xcodegen generate
   ```
3. **编译运行**:
   打开 `Maltex.xcodeproj`，选择 `Maltex`运行目标并点击运行。

## 🛠 技术栈

- **前端框架**: SwiftUI & Combine
- **核心引擎**: [aria2](https://aria2.github.io/)
- **通讯协议**: [Aria2Kit](https://github.com/baptistecdr/Aria2Kit) (RPC)
- **网络请求**: Alamofire
- **工程管理**: XcodeGen

## 🩺 问题排查

如果遇到引擎连接失败的问题：
1. **重置引擎**: 强制结束残留的 `aria2c` 进程：
   ```bash
   pkill -9 aria2c
   ```
2. **清理数据**: 如果配置文件损坏，可以尝试清理应用数据目录：
   ```bash
   rm -rf ~/Library/Application\ Support/Maltex
   ```
3. **查看日志**:
   - **应用日志**: `~/Library/Application Support/Maltex/maltex.log`
   - **引擎日志**: `~/Library/Application Support/Maltex/aria2.log`

## 🤝 参与贡献

欢迎任何形式的贡献、Bug 报告或功能建议！请参阅 [贡献指南](./CONTRIBUTING.md) 了解更多信息。

## 📜 开源协议

Maltex 基于 [MIT 协议](./LICENSE) 开源。

---
*源自 Motrix，为 macOS 而生。*
