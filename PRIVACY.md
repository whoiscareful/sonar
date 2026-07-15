# Privacy and data handling · 隐私与数据处理

This document describes HeartTone 1.0.0. HeartTone is a client for a server selected by the user; the project does not operate a central HeartTone account or analytics service.

本文适用于 HeartTone 1.0.0。HeartTone 是连接用户自选服务器的客户端；本项目不运营 HeartTone 中央账号或统计分析服务。

## English

### Data stored on the device

- The music-server password and optional Music Tag Web API token are stored in HarmonyOS Asset Store.
- Server settings, trusted Wi-Fi routing preferences, cache preferences, appearance settings, local playlists, and listening history are stored in the application sandbox.
- Song and artwork caches contain media obtained from the user-configured server.
- The Data Management page can delete caches, listening history, local playlists, appearance data, or all of these categories together.

### Network access

Depending on the features the user enables, HeartTone may contact:

- the remote or LAN Subsonic-compatible server configured by the user;
- the configured Music Tag Web Open API endpoint for optional lyrics, statistics, or profile synchronization;
- a supported music-platform public page or API when the user explicitly imports a shared playlist link.

HeartTone uses network and Wi-Fi state to select an endpoint and maintain playback. It does not upload a device address book, photo library, or unrelated local files.

### User-initiated import and export

- Playlist screenshot import sends no image to HeartTone infrastructure; OCR is performed through the on-device HarmonyOS Core Vision capability.
- Backup/export is explicit. An exported package can contain account configuration and other personal app data selected by the user. Treat exported files as sensitive and share them only through a trusted channel.
- Restore/import reads only the file or text chosen by the user.

### Repository and package privacy

- The public repository excludes signing certificates, provisioning profiles, keystores, passwords, tokens, local paths, and device identifiers.
- The tracked public HAP is unsigned. Debug-signed HAPs are not published because their provisioning profiles may contain device identifiers.
- Gitleaks is used against both the working tree and Git history before publication.

## 中文

### 本机保存的数据

- 音乐服务器密码和可选 Music Tag Web API Token 保存于 HarmonyOS Asset Store。
- 服务器设置、可信 Wi-Fi 路由偏好、缓存偏好、外观设置、本地歌单和听歌记录保存在应用沙箱中。
- 歌曲与封面缓存包含从用户配置服务器获取的媒体内容。
- “数据管理”页面可分别删除缓存、听歌记录、本地歌单、外观数据，或一次性清除这些类别。

### 网络访问

根据用户启用的功能，HeartTone 可能访问：

- 用户配置的远程或局域网 Subsonic 兼容服务器；
- 用户配置的 Music Tag Web Open API 端点，用于可选歌词、统计或资料同步；
- 用户主动导入歌单分享链接时，对应音乐平台的公开页面或接口。

HeartTone 使用网络和 Wi-Fi 状态选择访问端点并维持播放，不会上传通讯录、整个相册或无关本机文件。

### 用户主动触发的导入与导出

- 歌单截图导入不会上传到 HeartTone 基础设施；OCR 使用 HarmonyOS Core Vision 在设备侧处理。
- 备份 / 导出必须由用户主动触发。导出包可能包含账号配置以及用户选择的其他个人应用数据，应将其视为敏感文件，并仅通过可信渠道分享。
- 恢复 / 导入只读取用户主动选择的文件或文本。

### 仓库与安装包隐私

- 公开仓库排除签名证书、provisioning profile、密钥库、密码、Token、本机路径和设备标识。
- 仓库跟踪的公开 HAP 为 unsigned。调试签名 HAP 的 provisioning profile 可能包含设备标识，因此不会公开。
- 发布前使用 Gitleaks 同时扫描工作区与完整 Git 历史。
