/**
 * 通用 UI 表面毛玻璃参数。
 * 沉浸光感（systemMaterialEffect）在当前 SDK 仅可用于 HdsTabs 等 HDS 配置位点；
 * 卡片/按钮/输入框等 ArkUI 组件在此使用 COMPONENT_THICK 作为统一兜底。
 */
export class GlassSurfaceHelper {
  static readonly BLUR_STYLE: BlurStyle = BlurStyle.COMPONENT_THICK;
  static readonly BLUR_OPTIONS: BackgroundBlurStyleOptions = {
    colorMode: ThemeColorMode.SYSTEM,
    adaptiveColor: AdaptiveColor.DEFAULT,
    scale: 1.0
  };
}
