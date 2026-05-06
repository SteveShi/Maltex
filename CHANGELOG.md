# Changelog

All notable changes to this project will be documented in this file.

## [1.1.2] - 2026-05-07

### Fixed
- **Engine Race Condition**: Fixed a race condition where the termination handler of an old aria2 process could overwrite the state of a newly started process, causing the UI to incorrectly show "Aria2 engine stopped" during startup or restart.

---

### Chinese
### 修复
- **引擎启动竞态条件**: 修复了旧的 aria2 进程终止回调可能覆盖新启动进程状态的竞态条件。该问题曾导致在启动或重启内核时，UI 偶尔会错误地显示“Aria2 内核已停止”。

---

## [1.1.1] - 2026-04-26

### Changed
- **Task Intake Cleanup**: Consolidated duplicated RPC result handling for HTTP, Magnet, and Torrent task creation.
- **Torrent Confirmation Cleanup**: Removed unused selection state from the Torrent confirmation dialog.
- **Version Alignment**: Aligned the Safari extension version with the main app build settings.

### Removed
- **Temporary Search Output**: Removed a committed temporary grep output file.

---

### Chinese
### 调整
- **任务添加逻辑清理**: 合并 HTTP、Magnet 和 Torrent 任务创建中的重复 RPC 结果处理逻辑。
- **种子确认清理**: 移除种子确认窗口中未使用的选择状态。
- **版本一致性**: 将 Safari 扩展版本改为跟随主应用构建设置。

### 移除
- **临时搜索输出**: 移除误提交的临时 grep 输出文件。

---

## [1.1.0] - 2026-04-24

### Added
- **Tracker Source Management**: Select from preset tracker sources (ngosang/trackerslist, XIU2/TrackersListCollection) with CDN mirror support.
- **Custom Tracker Sources**: Add and manage custom tracker source URLs with validation.
- **One-Click Tracker Sync**: Fetch and merge tracker lists from multiple sources concurrently with proxy support.
- **Tracker Probing**: Probe tracker reachability with real-time status updates (online/offline/unknown) and protocol classification.
- **Remove Offline Trackers**: One-click removal of unreachable trackers from the list.
- **Auto-Sync on Launch**: Automatically sync tracker lists from selected sources when the app starts.
- **Engine Restart Prompt**: Prompt to restart the aria2 engine after tracker list updates.

### Fixed
- **Engine Restart Bug**: Fixed `restart()` not properly stopping the old process, causing engine restarts to silently fail.
- **BT Settings Not Applied**: Fixed BT-related settings (listen port, DHT port, UPnP, metadata saving, encryption) not being passed to aria2 engine.
- **numSeeders Decoding**: Fixed task list potentially failing to decode when aria2 returns numSeeders as a string.
- **Simultaneous Alerts**: Fixed partial sync success showing two alerts simultaneously in SwiftUI.

---

### Chinese
### 新增
- **Tracker 源管理**: 支持从预设 Tracker 源（ngosang/trackerslist、XIU2/TrackersListCollection）选择，含 CDN 镜像支持。
- **自定义 Tracker 源**: 添加和管理自定义 Tracker 源 URL，带 URL 验证。
- **一键同步 Tracker**: 从多个源并发抓取并合并去重 Tracker 列表，支持代理。
- **Tracker 探测**: 实时探测 Tracker 可达性（在线/离线/未知），按协议分类显示。
- **移除离线 Tracker**: 一键移除不可达的 Tracker。
- **启动时自动同步**: 应用启动时自动从选中的源同步 Tracker 列表。
- **引擎重启提示**: Tracker 列表更新后提示重启 aria2 引擎。

### 修复
- **引擎重启失败**: 修复 `restart()` 未正确停止旧进程，导致引擎重启静默失败的问题。
- **BT 设置未生效**: 修复 BT 相关设置（监听端口、DHT 端口、UPnP、元数据保存、加密）未传递给 aria2 引擎的问题。
- **numSeeders 解码错误**: 修复 aria2 返回字符串格式的 numSeeders 导致任务列表可能解码失败的问题。
- **Alert 冲突**: 修复部分同步成功时两个弹窗同时显示的问题。

---

## [1.0.0] - 2026-03-29

### Added
- **Sparkle Update Support**: Integrated Sparkle framework for seamless in-app updates.
- **Auto-Update Checks**: Added automatic update checking and a "Check for Updates..." menu item.
- **Version 1.0.0**: Officially bumped the version to 1.0.0.

### Chinese
### 新增
- **Sparkle 更新支持**: 集成了 Sparkle 框架，支持应用内无缝更新。
- **自动检查更新**: 添加了自动检查更新功能，并在菜单栏中新增了“检查更新...”选项。
- **版本 1.0.0**: 正式将版本号提升至 1.0.0。

## [0.9.2] - 2026-03-18

### Fixed
- **Download Data Staleness**: Resolved an issue where the download list would show 0 KB or stale progress. Improved `DownloadTask` equality tracking to trigger UI updates on progress changes.
- **Task Merging & Duplication**: Overhauled the RPC background merging logic to prevent GID collisions and ensure consistent state between the list and detail views.
- **HTTP Filename Parsing**: Enabled `content-disposition` support in the engine and implemented a smart filename extraction fallback in the UI to filter out random hex strings/GIDs.

## [0.9.1] - 2026-03-09

### Added
- **File Association & Drag/Drop**: Implemented reliable `.torrent` file drag-and-drop support into the main window and registered Maltex as a default application for `.torrent` files in macOS.
- **Dedicated Torrent Icon**: Added a professional `.icns` file icon specifically for `.torrent` files associated with Maltex.
- **Automated Testing Suite**: Implemented comprehensive unit tests covering JSON serialization, `DownloadTask` status enums, local storage validation, and byte formatters.

### Fixed
- **Task List Flickering**: Removed severe visual flickering in the main UI by consolidating Aria2 HTTP RPC polls into a single batched result, updating the view only once per cycle.
- **Torrent Dialogue Disappearing**: Resolved a bug where the Torrent confirmation dialogue would turn grey and reset itself on every task refresh cycle by injecting stable snapshot states.
- **HTTP Multi-Download Support**: Fixed the `addUri` method passing multiple URLs as a single Aria2 mirror string; URLs are now iterated and sent as independent downloads.
- **Localization Patches**: Dynamically extracted and translated missing Chinese strings for the UI and backend errors across the app.

## [0.9] - 2026-03-01

### Added
- **Aria2 Connection Status**: Added a live Aria2 connection status indicator in the General settings page with green/red dot states.
- **Torrent File Association**: Improved `.torrent` file association handling with explicit extension mapping and app delegate open-file callbacks.

### Fixed
- **Torrent Drop Confirmation**: Fixed an issue where dropping `.torrent` files could miss the confirmation popup due to metadata timing race conditions.
- **HTTP Download Intake**: Fixed HTTP/HTTPS URL intake for both in-app creation and external URL open handling.
- **Localization Coverage**: Completed missing localization keys and removed newly introduced hardcoded user-facing strings.
- **Compiler Type-Check Timeout**: Refactored `MainView` into smaller sub-expressions to resolve SwiftUI type-check timeout errors.
- **Settings Window Jitter**: Fixed settings window size jumping while switching tabs and constrained settings window dimensions below the main window.

### Changed
- **Version Update**: Bumped app version to `0.9` (`CURRENT_PROJECT_VERSION = 900`).
- **Engine Dev Binary Fallback**: Replaced user-specific absolute path fallback with architecture-aware relative fallback for `aria2c`.

## [0.8.3] - 2026-02-13

### Added
- **Full Localization**: Completed Simplified Chinese and English localization for all UI elements, including task details, settings, and menu bar.
- **Dynamic Status**: Implemented localized task status names.

### Improved
- **UI Strings**: Removed all hardcoded strings and moved them to string catalogs for better maintainability.
- **Torrent Confirm**: Refined the layout and localized content of the torrent confirmation dialog.

## [0.8.2] - 2026-02-06

### Fixed
- **Download History**: Fixed an issue where completed tasks could appear as duplicate entries in the history.

## [0.8.1.14] - 2026-01-29

### Fixed
- **Liquid Glass Design**: Refined the settings interface with proper corner radius and transparency to match Liquid Glass standards.
- **CI/CD Build**: Fixed an issue where system transparency effects were missing in builds distributed via GitHub Actions by adding Ad-hoc signing.
- **Safari Extension**: Fixed architecture thinning for the Safari Extension in the release workflow.
- **Release Notes**: Improved the automatic extraction of changelog notes in the release workflow for better accuracy.

## [0.8] - 2026-01-29

### Added
- **Liquid Glass Design**: Redesigned the entire application interface with a modern "Liquid Glass" (vibrancy/blur) aesthetic. This includes the sidebar, main content area, task details, and settings window.
- **Native Window Integration**: Enabled full-size content view and transparent title bars for a more integrated macOS experience.

### Changed
- **Engine Connection UX**: Removed the persistent "Connecting..." message during startup. The app now remains silent unless an engine error occurs.
- **Improved Error Handling**: Engine errors are now presented via native macOS alerts with retry options, reducing UI clutter.

## [0.7.1] - 2026-01-29

### Added
- **Localization**: Added comprehensive Chinese localization support across the application, adhering to standard practices.
- **Download History**: Implemented local history persistence (`HistoryStore`). Completed or removed tasks are now archived and can be viewed even after restarting the app.
- **Torrent Preview**: Enhanced the torrent confirmation dialog with a file list preview. Users can now:
    - View individual file sizes.
    - Select/Deselect all files.
    - Choose specific files to download.
- **Task Categories**: Added "All Tasks" and "Paused" categories to the sidebar for better task management.
- **Clipboard Detection**: The "Add Task" view now automatically detects and populates magnet links or HTTP/HTTPS URLs from the clipboard.

### Changed
- **UI Improvements**: Updated task status colors to be more intuitive:
    - 🔵 Blue: Downloading
    - ⚪️ Gray: Paused
    - 🔴 Red: Error/Stopped
    - 🟢 Green: Completed
- **Task Deletion**: Improved task removal logic to ensure "zombie" tasks are completely removed from both the engine and the UI.
- **File Association**: Added support for opening `.torrent` files and handling `magnet:` links directly within the app.

## [0.6] - 2026-01-18

### Fixed
- **Startup Crash**: Fixed a crash caused by notification permission request callback being executed on a background thread, violating Main Actor isolation.

### Changed
- **Version Update**: Bumped version to 0.6.

## [0.1] - 2026-01-15

### Fixed
- **Engine Connection Failure**: Resolved a critical issue where the Aria2 engine would fail to start or connect due to spaces in the macOS "Application Support" directory path.
- **App Crash during Logging**: Fixed a crash caused by concurrent write access to the same log file by both the Swift app and the Aria2 process.
- **Engine Startup Loop**: Fixed an issue where the engine would exit with code 28 when trying to load an empty or corrupted input file.
- **IPv6 Binding Conflicts**: Added `--disable-ipv6=true` to prevent the engine from failing to bind to ports on certain network configurations.

### Changed
- **Data Directory**: Migrated user data and engine logs to `~/Library/Application Support/Maltex` and optimized argument handling for paths with spaces.
- **Logging Architecture**: Separated application logs (`maltex.log`) from engine logs (`aria2.log`) and added a dedicated `aria2_stderr.log` for capturing runtime errors.
- **RPC Host**: Switched default RPC connection host from `127.0.0.1` to `localhost` to improve compatibility with local loopback interfaces.
- **Engine Arguments**: Simplified `aria2c` startup flags to increase reliability across different macOS environments.
