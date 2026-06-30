# HeartTone · 心音

> A HarmonyOS music client for self-hosted Subsonic / Navidrome servers, with foldable outer-screen support, dynamic bar-tone coloring, and a layered cache system.
> 一款专为自托管 Subsonic / Navidrome 服务器设计的 HarmonyOS 音乐客户端，支持折叠屏外屏、动态取色与分层缓存。

**English** | [中文](#中文版)

---

## English

HeartTone (心音) is a HarmonyOS music client compatible with the SonicAPI / Subsonic protocol. It is designed for self-hosted music services such as Navidrome, with first-class support for HarmonyOS 6.1+ visual effects, foldable devices, and offline caching.

> This project is a secondary development based on [Sonar](https://github.com/imba97/sonar) by imba97, maintained by whoiscareful.

### Highlights

- **SonicAPI / Subsonic compatible** — authentication, browsing, streaming, search
- **Remote + LAN endpoint switching** — automatically picks the local URL when connected to a trusted Wi-Fi SSID
- **Three-tab layout** — Music · Library · Profile, with HDS floating tab bar on HarmonyOS 6.1+ and a fallback Tabs shell on older APIs
- **Album library** — responsive grid (columns adapt to width), search, newest albums, album detail with play-all
- **Music list** — random / newest songs, kind segment switcher, pull-to-refresh
- **Now Playing** — cover-disc mode and fullscreen lyric mode with auto-hiding controls
- **Foldable outer screen** — compact player with current + next lyric line for cover-screen playback
- **Dynamic bar-tone coloring** — samples the album cover and animates the tab bar / title bar accent color
- **Layered cache** — song cache and cover cache with independent size limits (1 / 2 / 5 / 10 GB) and auto-cache modes (off / always / Wi-Fi only)
- **Background playback** — AVSession + long-running audio task + notification with play/pause controls
- **Next-track preloading** — multiple strategies (stream warmup, song-cache download, player standby) coordinated by a single orchestrator
- **Config import / export** — encrypted Base64 config sharing between devices
- **Glassmorphism UI** — HarmonyOS 6.0+ immersive material, glass surface, blur effects
- **Multi-device** — phone / tablet / 2-in-1, with outer-screen profile detection for foldables
- **TaskPool concurrency** — JSON parsing, Subsonic response parsing, and pixel-average color sampling run off the UI thread

### Tech Stack

- HarmonyOS `6.1.1` (API 24), compatible with `6.1.0` (API 23)
- ArkTS / ArkUI (Stage model)
- HarmonyOS Design System (HDS) — `HdsNavigation`, `HdsTabsShell`
- DevEco Studio + Hvigor build system

### Getting Started

#### 1) Prerequisites

- DevEco Studio 6.1.1 Release (with HarmonyOS SDK installed)
- A SonicAPI-compatible server account (e.g. Navidrome)
- Local signing materials for HarmonyOS app build

#### 2) Open Project

Open this folder in DevEco Studio and let dependencies sync.

#### 3) Configure Signing

The repository uses placeholder values in `build-profile.json5`. Replace the following fields with your local signing files and passwords:

- `certpath`
- `profile`
- `storeFile`
- `keyPassword`
- `storePassword`

Recommended: keep your actual certificate files outside the repository or under a local ignored path.

#### 4) Build and Run

Use DevEco Studio to run on emulator / device, or run the equivalent Hvigor tasks from terminal.

### Project Structure

```
HeartTone/
├─ AppScope/                         # App-level metadata and shared resources
│  ├─ app.json5                      # bundleName, icon, label
│  └─ resources/base/                # app icon (layered), app name
└─ sonar/                            # Entry HAP module (name kept as internal identifier)
   ├─ src/main/
   │  ├─ ets/
   │  │  ├─ sonarability/            # UIAbility entry
   │  │  ├─ sonarbackupability/      # Backup extension
   │  │  └─ sonar/
   │  │     ├─ api/                  # Subsonic client and types
   │  │     ├─ auth/                 # Credential / session persistence
   │  │     ├─ cache/                # Song cache, cover cache, eviction, settings
   │  │     ├─ common/               # Logger, network status, toast util
   │  │     ├─ components/           # UI components (buttons, forms, lists, lyrics, navigation, playback, playlist, settings)
   │  │     ├─ concurrency/          # TaskPool tasks (JSON parse, Subsonic parse, pixel average)
   │  │     ├─ crypto/               # Config encryption, MD5, random
   │  │     ├─ lyrics/               # Lyric parser
   │  │     ├─ navigation/           # Navigation platform adapter
   │  │     ├─ network/              # HTTP transport, endpoint router, media resource service
   │  │     ├─ pages/                # UI pages (Index, Login, Music, Library, AlbumDetail, NowPlaying, OuterScreenPlayer, CacheSettings, ExportConfig, Profile)
   │  │     ├─ playback/             # Playback service, session, pipeline, preload, background playback, AVSession
   │  │     ├─ settings/             # Music tab settings, recent history, config codec
   │  │     ├─ ui/                   # UI tokens, layout, material, color, adaptation
   │  │     ├─ view/                 # SonicAPI entry module
   │  │     └─ viewmodel/            # View models (Login, Music, Library, AlbumDetail, Lyric)
   │  ├─ resources/                  # Strings, colors, media, profiles
   │  └─ module.json5                # Module config, abilities, permissions
   ├─ oh-package.json5
   └─ build-profile.json5
```

### Pages

| Page | Description |
|---|---|
| `Index` | Root entry with floating tab bar and navigation host |
| `LoginPage` | Server login + Base64 config import (two tabs) |
| `MusicPage` | Random / newest song list with kind switcher and search |
| `LibraryPage` | Album grid with responsive columns and search |
| `AlbumDetailPage` | Album cover, song list, play-all / more menu |
| `NowPlayingPage` | Cover-disc mode + fullscreen lyric mode |
| `OuterScreenPlayerPage` | Compact player for foldable cover screen |
| `CacheSettingsPage` | Song / cover cache size and auto-mode settings |
| `ExportConfigPage` | Export encrypted login config as Base64 |
| `ProfilePage` | Server info, cache stats, export config, logout |

### Acknowledgements

- Original author: [imba97](https://github.com/imba97) — Sonar project
- Secondary development: [whoiscareful](https://github.com/whoiscareful) — HeartTone (心音)

### Open Source Notes

- Build artifacts, local dependencies, and IDE cache files are excluded via `.gitignore`
- Sensitive local signing values have been replaced by placeholders
- Project is released under the MIT License, see [LICENSE](./LICENSE)

---

## 中文版

HeartTone（心音）是一款 HarmonyOS 音乐客户端，兼容 SonicAPI / Subsonic 协议，专为 Navidrome 等自托管音乐服务设计，深度适配 HarmonyOS 6.1+ 视觉效果、折叠屏设备与离线缓存。

> 本项目基于 [Sonar](https://github.com/imba97/sonar)（作者 imba97）二次开发，由 whoiscareful 维护。

### 特性

- **SonicAPI / Subsonic 兼容** — 认证、浏览、流式播放、搜索
- **远程 / 本地 URL 自动切换** — 连接到可信 Wi-Fi SSID 时自动使用本地地址
- **三 Tab 布局** — 音乐 · 媒体库 · 我的，HarmonyOS 6.1+ 使用 HDS 浮动 Tab 栏，旧版 API 回退到普通 Tabs
- **专辑媒体库** — 响应式栅格（列数随宽度自适应）、搜索、最新专辑、专辑详情页支持全部播放
- **音乐列表** — 随机 / 最新歌曲、类型切换、下拉刷新
- **播放详情页** — 封面唱片模式 + 全屏歌词模式（控制按钮自动隐藏）
- **折叠屏外屏** — 精简播放器显示当前行与下一行歌词，支持合盖播放
- **动态取色** — 从专辑封面采样并动画过渡 Tab 栏 / 标题栏强调色
- **分层缓存** — 歌曲缓存与封面缓存独立配置，容量限制 1 / 2 / 5 / 10 GB，自动缓存模式支持 关闭 / 始终 / 仅 Wi-Fi
- **后台播放** — AVSession + 长时音频任务 + 通知栏播放控制
- **下一首预加载** — 多策略协同（流预热、缓存下载、播放器待机），由统一编排器调度
- **配置导入 / 导出** — 加密 Base64 配置，便于设备间迁移
- **玻璃拟态 UI** — 适配 HarmonyOS 6.0+ 沉浸式材质、玻璃表面、模糊效果
- **多设备适配** — 手机 / 平板 / 二合一，折叠屏自动识别外屏配置
- **TaskPool 并发** — JSON 解析、Subsonic 响应解析、像素平均取色均运行在子线程

### 技术栈

- HarmonyOS `6.1.1`（API 24），兼容 `6.1.0`（API 23）
- ArkTS / ArkUI（Stage 模型）
- HarmonyOS 设计系统（HDS）— `HdsNavigation`、`HdsTabsShell`
- DevEco Studio + Hvigor 构建系统

### 快速开始

#### 1) 前置条件

- DevEco Studio 6.1.1 Release（已安装 HarmonyOS SDK）
- 一个 SonicAPI 兼容服务器账号（例如 Navidrome）
- HarmonyOS 应用构建所需的本地签名材料

#### 2) 打开项目

在 DevEco Studio 中打开本目录，并让依赖同步完成。

#### 3) 配置签名

仓库中 `build-profile.json5` 使用占位值，请将以下字段替换为你本地的签名文件和密码：

- `certpath`
- `profile`
- `storeFile`
- `keyPassword`
- `storePassword`

建议：将实际的证书文件存放在仓库外或本地忽略路径下。

#### 4) 构建与运行

使用 DevEco Studio 在模拟器 / 真机上运行，或在终端中执行对应的 Hvigor 任务。

### 项目结构

```
HeartTone/
├─ AppScope/                         # 应用级元数据与共享资源
│  ├─ app.json5                      # bundleName、图标、应用名
│  └─ resources/base/                # 应用图标（分层）、应用名
└─ sonar/                            # Entry HAP 模块（模块名 sonar 沿用为内部标识）
   ├─ src/main/
   │  ├─ ets/
   │  │  ├─ sonarability/            # UIAbility 入口
   │  │  ├─ sonarbackupability/      # 备份扩展能力
   │  │  └─ sonar/
   │  │     ├─ api/                  # Subsonic 客户端与类型
   │  │     ├─ auth/                 # 凭据 / 会话持久化
   │  │     ├─ cache/                # 歌曲缓存、封面缓存、淘汰策略、设置
   │  │     ├─ common/               # 日志、网络状态、Toast 工具
   │  │     ├─ components/           # UI 组件（按钮、表单、列表、歌词、导航、播放、播放列表、设置）
   │  │     ├─ concurrency/          # TaskPool 任务（JSON 解析、Subsonic 解析、像素平均）
   │  │     ├─ crypto/               # 配置加密、MD5、随机
   │  │     ├─ lyrics/               # 歌词解析器
   │  │     ├─ navigation/           # 导航平台适配
   │  │     ├─ network/              # HTTP 传输、端点路由、媒体资源服务
   │  │     ├─ pages/                # UI 页面（Index、登录、音乐、媒体库、专辑详情、播放详情、外屏播放器、缓存设置、导出配置、我的）
   │  │     ├─ playback/             # 播放服务、会话、管线、预加载、后台播放、AVSession
   │  │     ├─ settings/             # 音乐 Tab 设置、最近播放、配置编解码
   │  │     ├─ ui/                   # UI Tokens、布局、材质、取色、适配
   │  │     ├─ view/                 # SonicAPI 入口模块
   │  │     └─ viewmodel/            # 视图模型（登录、音乐、媒体库、专辑详情、歌词）
   │  ├─ resources/                  # 字符串、颜色、媒体、profile
   │  └─ module.json5                # 模块配置、Ability、权限
   ├─ oh-package.json5
   └─ build-profile.json5
```

### 页面说明

| 页面 | 说明 |
|---|---|
| `Index` | 根入口，承载浮动 Tab 栏与导航宿主 |
| `LoginPage` | 服务器登录 + Base64 配置导入（双 Tab） |
| `MusicPage` | 随机 / 最新歌曲列表，支持类型切换与搜索 |
| `LibraryPage` | 专辑栅格（列数自适应）与搜索 |
| `AlbumDetailPage` | 专辑封面、曲目列表、全部播放 / 更多菜单 |
| `NowPlayingPage` | 封面唱片模式 + 全屏歌词模式 |
| `OuterScreenPlayerPage` | 折叠屏外屏精简播放器 |
| `CacheSettingsPage` | 歌曲 / 封面缓存容量与自动模式设置 |
| `ExportConfigPage` | 导出加密登录配置为 Base64 |
| `ProfilePage` | 服务器信息、缓存占用、导出配置、退出登录 |

### 致谢

- 原作者：[imba97](https://github.com/imba97) — Sonar 项目
- 二次开发：[whoiscareful](https://github.com/whoiscareful) — HeartTone（心音）

### 开源说明

- 构建产物、本地依赖、IDE 缓存文件均通过 `.gitignore` 排除
- 敏感的本地签名值已被替换为占位符
- 项目遵循 MIT 许可证，详见 [LICENSE](./LICENSE)
