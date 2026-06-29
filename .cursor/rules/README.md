# Sonar Cursor Rules 目录

`.cursor/rules/` 下的 `.mdc` 文件由 Cursor 自动扫描加载；子目录（`arkui/`、`hds/`、`media/`、`app/`）用于主题归类。本 README 仅供人工浏览，**不会**被当作 rule 加载。

若某条嵌套规则在 **Cursor Settings → Rules** 中不可见，可临时将该文件移回 `.cursor/rules/` 根目录（见 [Cursor Rules 文档](https://cursor.com/docs/rules)）。

## 目录结构

```
.cursor/rules/
├── README.md                 # 本文件
├── app/                      # 应用级配置（桌面图标、启动页等）
├── arkui/                    # ArkUI 声明式 UI
├── hds/                      # UI Design Kit（HDS）
└── media/                    # 音频播放与系统媒体中心
```

## 规则一览

### arkui/ — ArkUI 声明式 UI（10）

| 文件 | description | globs | alwaysApply |
| --- | --- | --- | --- |
| `overview.mdc` | ArkUI 声明式开发总览与 HDS/ArkUI 组件选型索引 | `sonar/**/*.ets` | false |
| `components-lifecycle.mdc` | 自定义组件、Builder 与生命周期 | `sonar/**/*.ets` | false |
| `state-management.mdc` | 状态管理 V1/V2 选型、装饰器与性能 | — | **true** |
| `layout-containers.mdc` | 布局容器选型、响应式与性能 | `sonar/**/*.ets` | false |
| `navigation-routing.mdc` | Navigation/NavPathStack 路由（非 HDS） | `sonar/**/*.ets` | false |
| `lists-performance.mdc` | 列表渲染、LazyForEach 与组件复用 | `sonar/**/*.ets` | false |
| `interaction-dialogs.mdc` | 交互事件、手势竞争与弹层/Sheet | `sonar/**/*.ets` | false |
| `theme-window-adaptation.mdc` | 深色模式、窗口安全区、软键盘与一多 | `sonar/**/*.ets` | false |
| `accessibility.mdc` | 无障碍与适老化 | `sonar/**/*.ets` | false |
| `animation.mdc` | ArkTS 动画开发规范 | — | **true** |

### hds/ — UI Design Kit（10）

| 文件 | description | globs | alwaysApply |
| --- | --- | --- | --- |
| `overview.mdc` | HDS 总览、版本约束与子规则索引 | — | **true** |
| `navigation.mdc` | HdsNavigation/HdsNavDestination 导航 | `**/*Navigation*.ets`, `**/pages/**` | false |
| `tabs-enhanced.mdc` | HdsTabs 增强（模糊/分割线/出血）；悬浮见 tabs-bar-floating | `**/*Tab*.ets` | false |
| `tabs-bar-floating.mdc` | 悬浮页签/miniBar 技术规范；展开宽度 UiTokens 三档 | — | **true** |
| `tabs-bar-floating-pitfalls.mdc` | 悬浮底栏历史回归与反模式（归档） | `**/*FloatingTabBar*.ets`, `**/*Tab*.ets`, `**/Index.ets` | false |
| `icon-symbol.mdc` | hdsDrawable 图标与 Symbol 注册 | `**/media/**`, `**/*Icon*.ets` | false |
| `visual-effects.mdc` | 点光源、按压阴影与流光 | `sonar/**/*.ets` | false |
| `list-card.mdc` | 列表横滑删除与卡片样式 | `**/*List*.ets`, `**/pages/**` | false |
| `sidebar-interaction.mdc` | 侧边栏、即时操作、核心操作栏与多窗 | — | false |
| `immersive-light-perception.mdc` | 沉浸光感材质 | — | **true** |

### media/ — 音频与媒体中心（2）

| 文件 | description | globs | alwaysApply |
| --- | --- | --- | --- |
| `audiorenderer-playback.mdc` | AudioRenderer 音频播放 | — | **true** |
| `avsession-media-center.mdc` | AVSession 系统媒体中心（Sonar） | — | **true** |

### app/ — 应用级配置（1）

| 文件 | description | globs | alwaysApply |
| --- | --- | --- | --- |
| `icon.mdc` | 应用图标（分层桌面图标 + 启动页） | `AppScope/**`, `**/module.json5`, … | false |

## 入口索引

- ArkUI 总览与选型：`arkui/overview.mdc`
- HDS 总览与版本门槛：`hds/overview.mdc`
- 桌面/启动图标：`app/icon.mdc`（应用内 HDS 图标见 `hds/icon-symbol.mdc`）

## 验收清单

1. Cursor Settings → Rules：应可见 **23** 条 `.mdc`（全部位于子目录，根目录仅 `README.md`）
2. 新对话中 **7** 条 `alwaysApply: true` 规则应自动注入上下文
3. 打开 `sonar/**/*.ets` 时，带 `globs` 的 arkui/hds 规则应可被关联
