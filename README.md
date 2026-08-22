# Rock YouTube Downloader

Rock 自用的 macOS YouTube 下载图形界面工具，使用 SwiftUI 编写，底层调用 `yt-dlp` 和 `ffmpeg`。

**当前整理版本：V6.1**

## 主要功能

- 粘贴 YouTube 视频网址并读取标题、频道、时长和封面
- 多档清晰度与仅音频下载
- 中文字幕、英文字幕、中英字幕及全部字幕选择
- 播放列表下载
- 自定义保存位置与文件命名
- 实时进度、速度和预计剩余时间
- 下载历史显示真实标题、封面、清晰度和时间
- 断点续传：暂停、继续，以及 App 重启后恢复未完成任务
- 检查/更新 `yt-dlp`，检查/安装 `ffmpeg`

## 目录

- `Sources/YTDownloader.swift`：App 主程序源码
- `Assets/AppIcon-1024.png`：App 图标源文件
- `Info.plist`：macOS App 配置
- `Scripts/一键生成App.command`：本机构建脚本
- `docs/`：旧版本说明
- `DISCLAIMER.md`：版权、平台规则与使用边界
- `THIRD_PARTY_NOTICES.md`：第三方软件说明
- `LICENSE`：本仓库自有代码许可证

## 构建

当前构建脚本原本与源码、`Info.plist`、图标放在同一目录运行。若直接使用本仓库目录结构，可将 `Scripts/一键生成App.command` 与 `Sources/YTDownloader.swift`、`Info.plist`、`Assets/AppIcon-1024.png` 临时放到同一文件夹后运行；后续版本会把构建脚本进一步适配为直接从当前仓库结构构建。

macOS 需要 Apple 的 Swift 编译工具。若系统未安装，脚本会提示运行 `xcode-select --install`。

## 版权与合法使用

本项目只是本地技术工具，**不会授予任何第三方视频或媒体内容的版权或下载许可**。使用者应确保自己对目标内容拥有下载、保存和后续使用所需的权利，并遵守适用的 YouTube 服务条款、版权政策、内容许可条件和当地法律。

不得使用本项目规避 DRM（数字版权管理）、付费墙、账户/订阅权限、访问控制或其他技术保护措施，也不得用于未经授权的批量复制、再发布或商业利用第三方内容。

本项目与 YouTube、Google 或 Google LLC **没有隶属、赞助、认可、授权或合作关系**。YouTube、Google 及相关商标归各自权利人所有。

完整说明见 [`DISCLAIMER.md`](DISCLAIMER.md)。

## 第三方项目

本 App 会调用用户电脑上安装的 `yt-dlp` 与 `ffmpeg`。它们是独立的第三方开源项目，许可和版权归各自项目及贡献者所有；本仓库的 MIT License 不会覆盖或替代它们各自的许可证。

详见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

## 本仓库许可证

本仓库作者拥有版权的源代码采用 MIT License，详见 [`LICENSE`](LICENSE)。该许可证仅适用于本仓库自有代码，不对任何 YouTube 视频、第三方媒体、第三方软件或商标进行再授权。
