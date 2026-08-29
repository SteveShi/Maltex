# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-08-30

### Added
- Added native SwiftUI `WhatsNewSheetView` to showcase key updates and improvements upon major app releases.

### Improved
- Redesigned sidebar engine connection status with minimalist indicator dots (🟢 Engine Ready, 🟠 Connecting, 🔴 Engine Error) to eliminate cramped layouts and text wrapping.
- Added one-click engine restart and reconnection button in the sidebar status bar on engine errors.

### Fixed
- Fixed an issue where clicking magnet links or opening external URLs would open duplicate main window instances by migrating to a single-instance `Window` scene with proper external event handling.

---

### Chinese
### 新增
- 新增大版本更新专属的 SwiftUI 原生 `WhatsNewSheetView`（新功能介绍）弹窗，直观呈现版本核心升级点。

### 改进
- 优化侧边栏底部内核连接状态显示，改为极简指示点与状态文案（🟢 内核正常、🟠 正在连接、🔴 内核错误），彻底解决侧边栏文字折行拥挤问题。
- 在内核发生错误时提供一键重启引擎与快速重连按钮。

### 修复
- 修复点击磁力链接或打开外部下载链接时会多弹出一个重复主界面的问题（将 `WindowGroup` 迁移为单实例 `Window` 场景并优化外部事件路由）。

---

## [1.1.20] - 2026-08-29

### Improved
- Redesigned sidebar engine connection status with minimalist indicator dots (🟢 Engine Ready, 🟠 Connecting, 🔴 Engine Error) to prevent label clipping and text wrapping.
- Added one-click engine restart and reconnection button in the sidebar status bar on engine errors.

---

### Chinese
### 改进
- 优化侧边栏底部内核连接状态显示，改为极简指示点与状态文案（🟢 内核正常、🟠 正在连接、🔴 内核错误），彻底解决侧边栏文字折行拥挤问题。
- 在内核发生错误时提供一键重启引擎与快速重连按钮。

---

## [1.1.19] - 2026-08-27

### Changed
- Updated bundled experimental download engine `aria2-next` to v2.6.4 (ARM64 and x86_64).
- Upgraded `Aria2Kit` dependency to 1.0.7 (Alamofire 5.12.0) and resolved `AnyEncodable` namespace collision.

---

### Chinese
### 变更
- 更新内置实验性下载引擎 `aria2-next` 至 v2.6.4 (ARM64 & x86_64)。
- 升级 `Aria2Kit` 依赖至 1.0.7 (Alamofire 5.12.0)，并解决 `AnyEncodable` 命名空间冲突。

---

## [1.1.18] - 2026-08-06

### Added
- Added Speed Display Mode Picker setting in General Settings ("Display Both", "Menu Bar Icon Only", "Dock Icon Only").

### Fixed
- Fixed menu bar popover ScrollView height collapsing issue when displaying active tasks.

---

### Chinese
### 新增
- 常规设置中增加“实时速度显示” Picker 选项（可切换“同时显示”、“只显示菜单栏图标”、“只显示 Dock 图标”）。

### 修复
- 修复菜单栏弹窗中活跃任务列表的高度坍塌隐没问题。

---

## [1.1.17] - 2026-08-06

### Improved
- Dynamic button state validation in task list toolbar and context menu: "Start" and "Pause" buttons are now dynamically enabled or disabled based on selected task statuses (e.g., "Start" is disabled when tasks are downloading).
- Optimized BT download pause speed with instant optimistic UI response and `forcePause` RPC invocation.

---

### Chinese
### 改进
- 优化任务列表工具栏与右键菜单的按钮可用状态判定：根据当前选中任务的实际状态（下载中、已暂停、已完成）动态开启或禁用“开始”和“暂停”按钮（例如：任务下载中时自动禁用“开始”按钮）。
- 优化 BT 任务暂停响应速度：使用 `forcePause` 并结合本地乐观 UI 状态更新，实现点击暂停的毫秒级即时响应。

---

## [1.1.16] - 2026-08-06

### Improved
- Redesigned menu bar popover with modern card-based layout (`MenuBarExtraStyle.window`).
- Active download tasks now display file name, progress bar, real-time speed, downloaded/total size, and percentage in the menu bar popover.
- Real-time total download speed is shown next to the menu bar icon when downloads are active.
- Completed downloads are no longer shown in the menu bar download list.
- Added `displayName` computed property to `DownloadTask` for friendly file name display throughout the app.

### Fixed
- Fixed an issue where the real-time speed display on the Dock icon stopped updating after closing the main window.
- Fixed misaligned form controls in Settings (Aria2 source, file/session, download, and HTTP sections).

---

### Chinese
### 改进
- 重新设计菜单栏弹窗为现代卡片式布局（`MenuBarExtraStyle.window`）。
- 活跃下载任务在菜单栏弹窗中显示文件名、进度条、实时速度、已下载/总大小及百分比。
- 下载中时，菜单栏图标旁实时显示当前总下载速度。
- 已完成的下载不再显示在菜单栏下载列表中。
- 为 `DownloadTask` 增加 `displayName` 计算属性，提供友好文件名显示。

### 修复
- 修复主界面关闭后，Dock 图标上的实时下载速度显示无法刷新的问题。
- 修复设置页面中 Aria2 来源、文件与会话、下载任务、HTTP 等区域表单控件未对齐的问题。

---

## [1.1.13] - 2026-08-03

### Added
- System notifications (`UNUserNotificationCenter`) for download failure events.
- Detailed error reason display (`errorMessage` and localized error descriptions) in the task list (`TaskRow`) and task details view (`TaskDetailView`).

### Fixed
- Fixed an issue where the detail tray remained open when a task moved to another category upon download completion or error.

---

### Chinese
### 新增
- 增加下载任务失败时的系统本地通知提示 (`UNUserNotificationCenter`)。
- 在任务列表项 (`TaskRow`) 与任务详情视图 (`TaskDetailView`) 中补充详细的错误原因解析与展示。

### 修复
- 修复下载完成或出错后任务迁移分类时，详情托盘未自动收起的问题。

---

## [1.1.12] - 2026-07-30

### Changed
- Updated bundled experimental download engine `aria2-next` to v2.5.3 (ARM64 and x86_64).

### Added
- Open Source Acknowledgements & Licenses document (`ACKNOWLEDGEMENTS.md`) for third-party component compliance.
- License & Acknowledgements section in General Settings with direct links to Maltex, Aria2, and GPLv2 license documentation.

### Fixed
- Clarified licensing details: Maltex is licensed under MIT, while bundled aria2/aria2-next engines operate under GPLv2 via process isolation.
- Corrected aria2-next source repository URL reference in documentation (`AnInsomniacy/aria2-next`).

---

### Chinese
### 变更
- 更新内置实验性下载引擎 `aria2-next` 至 v2.5.3 (ARM64 & x86_64)。

### 新增
- 增加开源致谢与许可声明文档 (`ACKNOWLEDGEMENTS.md`)，完善第三方组件合规说明。
- 在常规设置中增加“关于与开源协议”区域，提供 Maltex、Aria2 源码及 GPLv2 协议直链。

### 修复
- 明确许可证边界：Maltex 保持 MIT 协议开源，内置 aria2/aria2-next 引擎基于进程间隔离按 GPLv2 协议分发。
- 修正文档中实验内核 aria2-next 的官方仓库链接 (`AnInsomniacy/aria2-next`)。

---

## [1.1.11] - 2026-07-23

### Changed
- Removed unused `Alamofire` dependency and streamlined internal codebase.
- Optimized Foundation byte count formatters, date formatters, and protocol parsing to rely on native Swift standard library APIs.
- Cleaned up repository structure and internal documentation.

---

### Chinese
### 变更
- 移除未使用的 `Alamofire` 第三方依赖包，精简内部代码架构。
- 优化 Foundation 格式化工具与 URL 协议解析，全面采用 Swift 标准库原生 API。
- 清理项目工程架构与冗余内部文件。

---

## [1.1.10] - 2026-07-21

### Fixed
- Corrected Dock icon download speed calculation to only sum speeds of active downloading tasks, excluding completed, seeding, and archived tasks.
- Fixed an issue where archived historical tasks retained leftover download speed and connection metrics after app restoration.

---

### Chinese
### 修复
- 修正 Dock 图标实时下载速度统计逻辑，仅计算真正处于下载状态的活跃任务，排除已完成、做种与归档任务。
- 修复已完成的历史任务在归档及离线恢复后残留瞬时网速与后台连接数的问题。

---

## [1.1.9] - 2026-06-26

### Fixed
- Always show the torrent confirmation sheet before starting a `.torrent` download, regardless of the Magnet auto-start setting.
- Detect BitTorrent seeding after the file payload finishes, show those tasks as uploading, and keep them out of the active downloading list.
- Send completion notifications and restore completed history for BitTorrent tasks that remain active while seeding.

### Changed
- Renamed the BitTorrent auto-start setting so it only refers to Magnet links; `.torrent` files now require confirmation before starting.

---

### Chinese
### 修复
- 打开 `.torrent` 文件时总是先显示种子确认界面，不再受磁力链接自动开始设置影响。
- 下载内容完成后识别 BitTorrent 做种阶段，将这类任务显示为正在上传，并从正在下载列表中移出。
- 对仍在做种的 BitTorrent 任务发送下载完成通知，并恢复其已完成历史记录。

### 变更
- 调整 BitTorrent 自动开始设置文案，使其只指向磁力链接；`.torrent` 文件现在会先确认再开始。

---

## [1.1.8] - 2026-06-09

### Added
- Copy the direct download link (HTTP/FTP source URL) from the task list right-click menu and the task detail view.
- Optionally delete the downloaded files from disk when removing a task. Deleting now shows a confirmation with “Delete task and files” / “Delete task only”.
- ED2K link support: the new-task window detects `ed2k://` from the clipboard, and Maltex registers as a handler for `ed2k://` links (works with the experimental aria2-next engine).
- The new-task window now shows an engine-aware hint, and warns — with a one-click engine switch — when ED2K/Thunder links are entered while the standard engine is active.

### Changed
- Aligned the engine-source picker with the description text below it in Aria2 settings.
- Updated the README (English/Chinese) to reflect the actual aria2-next capabilities (ED2K, Thunder, decimal speed limits, share-only seeding, copy link).

---

### Chinese
### 新增
- 在任务列表右键菜单与任务详情中复制直链下载地址（HTTP/FTP 源地址）。
- 删除任务时可选择同步删除已下载到磁盘的文件，删除会弹出确认：“删除任务和文件” / “仅删除任务”。
- 支持 ED2K 链接：新建任务窗口自动识别剪贴板中的 `ed2k://`，并将 Maltex 注册为 `ed2k://` 链接的处理程序（需配合实验内核 aria2-next）。
- 新建任务窗口根据当前内核显示链接提示；在标准内核下输入 ED2K/迅雷链接时给出警告，并提供一键切换到实验内核。

### 变更
- 修正 Aria2 设置中“内核来源”选项框与下方说明文字的对齐。
- 更新中英文 README，反映 aria2-next 的真实能力（ED2K、迅雷、小数限速、仅做种控制、复制链接）。

---

## [1.1.7] - 2026-06-09

### Fixed
- Fixed a critical crash that made the app crash immediately on launch (the Dock download-speed indicator accessed AppKit before the application finished initializing).
- Fixed an untranslated fallback label ("Unknown task") in the task detail view.

### Changed
- Updated the bundled experimental aria2-next engine to 2.4.6. Since aria2-next 2.4.0 realigned to the standard aria2 (v2.1.4) baseline, engine arguments now use the standard option set; options that no longer exist in 2.4.x (and could prevent the engine from starting) were removed.

### Added
- Copy magnet / ED2K link from the task list context menu and the detail view (uses aria2-next 2.4.4 link fields, with a magnet fallback derived from the info hash).
- Share-only seeding control (`--detach-share-only`, aria2-next only).
- Decimal units for speed limits, e.g. `1.5M` (decimal units require aria2-next).

### Removed
- Removed obsolete aria2-next-specific settings (proxy mode, dedicated log levels/rotation, torrent-metadata mode) and the non-functional UPnP toggle.

---

### Chinese
### 修复
- 修复启动即崩溃的严重问题（Dock 下载速度指示器在应用初始化完成前访问了 AppKit）。
- 修复任务详情中未本地化的兜底文案（“未知任务”）。

### 变更
- 内置实验内核 aria2-next 更新至 2.4.6。由于 aria2-next 自 2.4.0 起回退到标准 aria2(v2.1.4) 基线，引擎参数改用标准选项集；移除了 2.4.x 已不存在、会导致内核无法启动的选项。

### 新增
- 在任务列表右键菜单与详情页复制磁力 / ED2K 链接（使用 aria2-next 2.4.4 的链接字段，BT 任务可由 info hash 兜底生成磁力链接）。
- 仅做种分享控制（`--detach-share-only`，仅 aria2-next 生效）。
- 限速支持小数单位，如 `1.5M`（小数单位需 aria2-next）。

### 移除
- 移除已失效的 aria2-next 专属设置（代理模式、独立日志级别/轮转、种子元数据模式）与不再生效的 UPnP 开关。

---

## [1.1.6] - 2026-06-09

### Added
- **Download Location Picker**: The new download dialog now lets you choose a save location per task, pre-filled with the default download path.
- **Live Download Speed in Dock**: The Dock icon can display the aggregate real-time download speed, with a toggle in General settings.
- **Estimated Time Remaining**: The download list and task detail now show the estimated time remaining for active downloads.
- **Task Added Time**: The task detail view now shows when a task was added.

### Changed
- **Completed List Ordering**: Completed downloads are now sorted by completion time, with the most recent at the top.

---

### Chinese
### 新增
- **下载位置选择**: 新建下载任务界面支持为每个任务单独选择保存位置，默认填入设置中的下载路径。
- **Dock 实时下载速度**: Dock 图标可显示当前总下载速度，可在"常规"设置中开关。
- **预计剩余时间**: 下载列表与任务详情会显示下载中任务的预计剩余时间。
- **任务添加时间**: 任务详情新增任务添加时间的显示。

### 变更
- **已完成列表排序**: 已完成的下载现按完成时间排序，最新完成的排在最前。

---

## [1.1.5] - 2026-05-31

### Added
- **Aria2 Next Experimental Engine**: Integrated aria2-next 2.3.6 as an experimental download engine option.
  - Added support for both arm64 and x64 architectures.
  - Implemented binary verification mechanism to ensure integrity before startup.
  - Added three-layer auto-fallback protection: verification failure, launch failure, and immediate crash all trigger automatic fallback to bundled aria2.
  - Added UI settings for aria2-next specific features:
    - Proxy mode (auto/direct/manual)
    - Torrent metadata handling (save/start/memory)
    - Terminal and file log levels with rotation settings
  - Handled aria2-next specific parameters: `--torrent-metadata`, `--proxy-mode`, `--terminal-log-level`, `--file-log-level`, `--log-file`, `--log-max-size`, `--log-max-files`, `--bt-force-encryption`.
  - Excluded unsupported parameters for aria2-next: `--bt-request-peer-speed-limit`, `--disable-upnp`.

### Changed
- **Engine Manager**: Enhanced startup logic with binary verification and automatic fallback mechanism.
- **Settings UI**: Dynamically show/hide options based on selected engine type.

---

### Chinese
### 新增
- **Aria2 Next 实验性内核**: 集成 aria2-next 2.3.6 作为实验性下载引擎选项。
  - 添加 arm64 和 x64 双架构支持。
  - 实现二进制验证机制，确保启动前文件完整性。
  - 添加三层自动降级保护：验证失败、启动失败、立即崩溃均会自动回退到标准 aria2。
  - 添加 aria2-next 特有功能的 UI 设置：
    - 代理模式（自动/直连/手动）
    - 种子元数据处理（仅保存/保存并开始/仅内存启动）
    - 终端和文件日志级别及轮转设置
  - 处理 aria2-next 特有参数：`--torrent-metadata`、`--proxy-mode`、`--terminal-log-level`、`--file-log-level`、`--log-file`、`--log-max-size`、`--log-max-files`、`--bt-force-encryption`。
  - 排除 aria2-next 不支持的参数：`--bt-request-peer-speed-limit`、`--disable-upnp`。

### 变更
- **引擎管理器**: 增强启动逻辑，添加二进制验证和自动降级机制。
- **设置界面**: 根据选择的引擎类型动态显示/隐藏选项。

---

## [1.1.4] - 2026-05-30

### Fixed
- **Dummy Preferences**: Integrated all previously inactive settings options into real download routines.
  - Linked `btAutoStart` to determine automatic download state of `.torrent` and `magnet:` files, bypassing prompt when enabled.
  - Connected `autoResumeTasks` to call `unpauseAll` RPC on app launch after successful connection.
  - Removed redundant `listenPort` from settings store, and purged the non-rendered `EngineSettingsView` from settings views.
- **DownloadTask Test Fix**: Fixed a bug in `testHashableEquality` where different status tasks were incorrectly expected to be equal under custom `==` override.

### Changed
- **Dependencies Update**: Upgraded Aria2Kit dependency to 1.0.5 and Alamofire dependency to 5.11.2 to resolve version compatibility.

---

### Chinese
### 修复
- **虚设设置项**: 接入此前未生效的虚设设置选项到实际逻辑中。
  - 关联 `btAutoStart` 设置，自动决定种子和磁力链接的自动开始状态，开启时直接启动并跳过弹窗确认。
  - 关联 `autoResumeTasks` 设置，在应用成功连接 RPC 后自动调用 `unpauseAll` 批量恢复所有未完成的任务。
  - 清理了未渲染的 `EngineSettingsView` 页面以及其中与 `btPort` 冲突的冗余配置项 `listenPort`。
- **单元测试修复**: 修正了 `testHashableEquality` 中由于自定义 `==` 比对 status 导致的不同任务断言相等的 bug。

### 变更
- **依赖项更新**: 将 Aria2Kit 依赖升级至 1.0.5，同时将 Alamofire 依赖升级至 5.11.2 以解决版本兼容性问题。

---

## [1.1.3] - 2026-05-23

### Fixed
- **Polling Deadlock**: Added generation tokens and a 10s timeout to the aggregated task fetch state machine, so a stuck RPC response no longer freezes the task list forever.
- **Main-Thread Torrent IO**: `addTorrent` now reads the .torrent file off the main thread, preventing UI hangs with large torrents.
- **Remove Task Consistency**: When a removal RPC fails on the engine side, the affected tasks are now restored to the UI and an error is surfaced instead of silently disappearing.
- **changeOption Error Propagation**: `resumeTask` no longer unpauses a task when its option change fails; the user is notified instead.
- **Concurrency Storm on Bulk Add**: Multiple URIs added at once are now serialized through an internal action queue, avoiding flooding aria2's single-threaded RPC.

### Changed
- **HTTPS RPC Support**: The RPC client now honors a new "Use HTTPS" setting instead of hard-coding HTTP.
- **Deferred Notification Permission**: Notification authorization is requested on the first actual delivery rather than at app launch.
- **Concurrency Hygiene**: Removed `nonisolated(unsafe)` from TaskStore's fetch state, reusing a single `JSONDecoder`, and made `Aria2Response.id` tolerate string / number / null per JSON-RPC 2.0.
- **Engine Shutdown**: TaskStore no longer schedules a MainActor task in `deinit`; engine shutdown remains the responsibility of `applicationWillTerminate`.

---

### Chinese
### 修复
- **轮询死锁**: 任务聚合抓取增加代数令牌和 10 秒超时保护，避免某次 RPC 卡死后任务列表永久停止刷新。
- **主线程读取种子**: `addTorrent` 改为异步读取 `.torrent` 文件，大种子不再卡住 UI。
- **删除任务一致性**: 引擎端删除失败时，UI 会回滚被误删的任务并给出错误提示，不再静默丢失。
- **changeOption 错误传递**: `resumeTask` 在选项修改失败时不会再 unpause，并向用户反馈失败原因。
- **批量添加并发风暴**: 一次性添加多个 URI 时改用串行队列下发，避免对 aria2 单线程 RPC 形成并发洪峰。

### 变更
- **支持 HTTPS RPC**: 新增"使用 HTTPS 连接"设置项，RPC 客户端不再硬编码为 http。
- **延迟通知权限申请**: 改为在第一次实际发送通知前请求权限，避免应用启动即弹系统对话框。
- **并发安全清理**: 移除 TaskStore 抓取状态上的 `nonisolated(unsafe)`，统一复用 `JSONDecoder`，并让 `Aria2Response.id` 按 JSON-RPC 2.0 兼容 string / number / null。
- **引擎关闭**: TaskStore 的 `deinit` 不再调度 MainActor Task，引擎停止统一由 `applicationWillTerminate` 兜底。

---

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
