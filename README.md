# HeartTone · 心音

> A native HarmonyOS music client for self-hosted Subsonic / Navidrome servers.
> 面向自托管 Subsonic / Navidrome 服务器的原生 HarmonyOS 音乐客户端。

**English** · [中文](#中文版) · [Privacy / 隐私](./PRIVACY.md) · [Changelog / 更新日志](./CHANGELOG.md)

Current source release: **1.0.0**

---

## English

HeartTone is an ArkTS / ArkUI music client compatible with SonicAPI and the Subsonic protocol. It is designed for private music libraries and adapts to HarmonyOS phones, tablets, 2-in-1 devices, and foldable outer screens.

This project is a secondary development based on [Sonar](https://github.com/imba97/sonar) by imba97.

### Highlights

- Subsonic-compatible authentication, browsing, search, streaming, favorite synchronization, and server scrobbling.
- Remote and LAN endpoint routing, including trusted Wi-Fi based local-address switching.
- Music feeds for favorites, random, frequently played, recently played, and newest tracks.
- Responsive album library, album details, song sorting, multi-select actions, and play-next controls.
- Local playlist creation, editing, sorting, artwork, transfer, and import from shared links, screenshots/OCR, or pasted song lists.
- Full-screen synchronized lyrics with optional Music Tag Web Open API enrichment and Subsonic fallback.
- Background playback through AVSession and a long-running audio task, plus next-track preload strategies.
- Song and cover caches with independent capacity and automatic-download policies.
- Listening statistics, recent history, sleep timer, profile personalization, and granular local-data deletion.
- Explicit backup and restore for account configuration, playlists, listening history, appearance, and cache preferences.
- Foldable outer-screen player, responsive layouts, glass surfaces, dynamic cover-color sampling, and dark mode.
- Secrets such as the server password and optional Open API token are stored in HarmonyOS Asset Store.

### Platform

- Target SDK `6.1.1` (API 24)
- Compatible SDK `6.1.0` (API 23)
- ArkTS / ArkUI, Stage model
- DevEco Studio and Hvigor

### Build

1. Install DevEco Studio 6.1.1 Release and the matching HarmonyOS SDK.
2. Open the repository and allow OHPM / Hvigor dependencies to synchronize.
3. Configure application signing locally in DevEco Studio if a signed, installable HAP is required.
4. Build the `hearttone` module for the `default` product.

The tracked `build-profile.json5` intentionally contains no certificate path, profile, keystore, alias, or password. Never commit any of the following fields with local values:

- `certpath`
- `profile`
- `storeFile`
- `keyAlias`
- `keyPassword`
- `storePassword`

The helper script can build and open a locally signed package after signing is configured:

```powershell
.\build-and-install.ps1 -InstallMode Installer -InstallerPath '<trusted-installer.exe>'
```

For direct HDC installation, pass a trusted local `hdc.exe` path or set `HDC_PATH`:

```powershell
.\build-and-install.ps1 -InstallMode Hdc -HdcPath '<hdc.exe>'
```

### Public HAP artifact

The repository tracks [HeartTone-1.0.0-unsigned.hap](./artifacts/HeartTone-1.0.0-unsigned.hap) together with [SHA256SUMS.txt](./artifacts/SHA256SUMS.txt).

The public artifact is deliberately **unsigned**. A HarmonyOS debug-signed HAP can embed a provisioning profile containing device identifiers, so debug signing materials and debug-signed packages are not published. Sign the unsigned HAP with your own trusted certificate/profile before installation or distribution.

### Privacy and security

- No signing certificates, provisioning profiles, keystores, device identifiers, access tokens, server addresses, or passwords are committed.
- Server passwords and optional Music Tag Web tokens use HarmonyOS Asset Store.
- Playback history, playlists, appearance data, and caches remain local unless the user explicitly exports a backup.
- Optional online features contact only the user-configured music server, the configured Music Tag Web endpoint, or a playlist platform selected during import.
- Gitleaks scans the working tree and Git history; the repository also includes an optional pre-commit hook.

Enable the hook once per clone:

```bash
git config core.hooksPath .githooks
```

Read [PRIVACY.md](./PRIVACY.md) before distributing the app or sharing exported backups.

### Main pages

| Page | Purpose |
|---|---|
| `MusicPage` | Favorite/random/frequent/recent/newest feeds, search, sorting, and multi-select |
| `LibraryPage` | Responsive album library and discovery |
| `AlbumDetailPage` | Album information, song actions, and playlist operations |
| `NowPlayingPage` | Cover player, synchronized lyrics, queue, favorites, and sleep timer |
| `PlaylistLibraryPage` | Local playlist management |
| `PlaylistImportPage` | Link, OCR, and text-based playlist import |
| `PlaylistDetailPage` | Playlist playback, ordering, selection, and editing |
| `PlaylistTransferPage` | Playlist copy / transfer workflow |
| `MusicStatsPage` | Local listening metrics and optional server statistics |
| `PersonalizationSettingsPage` | Avatar, background, blur, mask, and image API settings |
| `DataManagementPage` | Granular deletion of caches and local personal data |
| `ExportConfigPage` | Backup and restore |
| `CacheSettingsPage` | Song and artwork cache policies |
| `ProfilePage` | Server, personalization, statistics, backup, data, and sign-out entry points |
| `OuterScreenPlayerPage` | Foldable cover-screen playback UI |

### License and acknowledgements

- Original project: [imba97/sonar](https://github.com/imba97/sonar)
- HeartTone maintenance and secondary development: [whoiscareful](https://github.com/whoiscareful)
- License: [MIT](./LICENSE)

---

## 中文版

HeartTone（心音）是一款使用 ArkTS / ArkUI 开发的原生 HarmonyOS 音乐客户端，兼容 SonicAPI 与 Subsonic 协议，面向个人自托管音乐库，并适配手机、平板、二合一设备和折叠屏外屏。

本项目基于 imba97 的 [Sonar](https://github.com/imba97/sonar) 进行二次开发。

### 主要特性

- 兼容 Subsonic 的认证、浏览、搜索、流式播放、收藏同步与服务器播放记录上报。
- 支持远程 / 局域网端点路由，可按可信 Wi-Fi 自动切换本地地址。
- 提供收藏、随机、常听、最近播放和最新歌曲等音乐分类。
- 响应式专辑媒体库、专辑详情、歌曲排序、多选操作和下一首播放。
- 支持本地歌单创建、编辑、排序、封面、转移，以及分享链接、截图 OCR 或文本歌单导入。
- 全屏同步歌词；可选 Music Tag Web Open API 增强，失败时回退到 Subsonic 歌词。
- 基于 AVSession 和长时音频任务的后台播放，以及多策略下一首预加载。
- 歌曲与封面分层缓存，可分别设置容量和自动下载策略。
- 听歌统计、最近播放、睡眠定时、个人主页外观和细粒度本地数据删除。
- 主动触发的备份与恢复，可覆盖账号配置、歌单、听歌记录、外观和缓存偏好。
- 折叠屏外屏播放器、响应式布局、玻璃材质、封面动态取色和深色模式。
- 服务器密码与可选 Open API Token 使用 HarmonyOS Asset Store 保存。

### 平台基线

- 目标 SDK `6.1.1`（API 24）
- 兼容 SDK `6.1.0`（API 23）
- ArkTS / ArkUI，Stage 模型
- DevEco Studio 与 Hvigor

### 构建

1. 安装 DevEco Studio 6.1.1 Release 及对应 HarmonyOS SDK。
2. 打开仓库并等待 OHPM / Hvigor 依赖同步完成。
3. 如需可安装的签名 HAP，仅在本机 DevEco Studio 中配置应用签名。
4. 为 `default` 产品构建 `hearttone` 模块。

仓库跟踪的 `build-profile.json5` 有意不包含证书路径、profile、密钥库、别名或密码。请勿提交以下字段的本机值：

- `certpath`
- `profile`
- `storeFile`
- `keyAlias`
- `keyPassword`
- `storePassword`

完成本机签名配置后，可使用辅助脚本构建并打开签名包：

```powershell
.\build-and-install.ps1 -InstallMode Installer -InstallerPath '<可信安装器.exe>'
```

如需通过 HDC 直接安装，请传入可信的本机 `hdc.exe` 路径或设置 `HDC_PATH`：

```powershell
.\build-and-install.ps1 -InstallMode Hdc -HdcPath '<hdc.exe>'
```

### 公开 HAP 产物

仓库跟踪 [HeartTone-1.0.0-unsigned.hap](./artifacts/HeartTone-1.0.0-unsigned.hap)，并提供 [SHA256SUMS.txt](./artifacts/SHA256SUMS.txt) 校验文件。

公开产物特意保持为 **unsigned**。HarmonyOS 调试签名 HAP 可能内嵌包含设备标识的 provisioning profile，因此本仓库不会公开调试签名材料或调试签名包。安装或分发前，请使用你自己的可信证书与 profile 对 unsigned HAP 进行签名。

### 隐私与安全

- 仓库不提交签名证书、provisioning profile、密钥库、设备标识、访问令牌、服务器地址或密码。
- 服务器密码和可选 Music Tag Web Token 使用 HarmonyOS Asset Store 保存。
- 听歌记录、歌单、外观数据和缓存默认仅保存在本机，除非用户主动导出备份。
- 可选在线功能仅访问用户配置的音乐服务器、配置的 Music Tag Web 端点，或用户导入歌单时选择的平台。
- 使用 Gitleaks 扫描工作区与完整 Git 历史，并提供可选的提交前钩子。

每次克隆后执行一次以下命令即可启用钩子：

```bash
git config core.hooksPath .githooks
```

分发应用或分享导出备份前，请阅读 [PRIVACY.md](./PRIVACY.md)。

### 主要页面

| 页面 | 用途 |
|---|---|
| `MusicPage` | 收藏 / 随机 / 常听 / 最近 / 最新歌曲、搜索、排序与多选 |
| `LibraryPage` | 响应式专辑媒体库与发现 |
| `AlbumDetailPage` | 专辑信息、歌曲操作与歌单功能 |
| `NowPlayingPage` | 封面播放器、同步歌词、队列、收藏与睡眠定时 |
| `PlaylistLibraryPage` | 本地歌单管理 |
| `PlaylistImportPage` | 分享链接、OCR 和文本歌单导入 |
| `PlaylistDetailPage` | 歌单播放、排序、多选与编辑 |
| `PlaylistTransferPage` | 歌单复制 / 转移流程 |
| `MusicStatsPage` | 本地听歌指标与可选服务器统计 |
| `PersonalizationSettingsPage` | 头像、背景、模糊、遮罩与图片 API 设置 |
| `DataManagementPage` | 细粒度删除缓存和本地个人数据 |
| `ExportConfigPage` | 备份与恢复 |
| `CacheSettingsPage` | 歌曲与封面缓存策略 |
| `ProfilePage` | 服务器、个性化、统计、备份、数据和退出入口 |
| `OuterScreenPlayerPage` | 折叠屏外屏播放界面 |

### 许可与致谢

- 原项目：[imba97/sonar](https://github.com/imba97/sonar)
- HeartTone 二次开发与维护：[whoiscareful](https://github.com/whoiscareful)
- 许可证：[MIT](./LICENSE)
