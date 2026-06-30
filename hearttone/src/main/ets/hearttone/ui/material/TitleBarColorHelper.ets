import {
  HdsNavigationBackgroundStyle,
  HdsTitleBarContentStyle
} from '@kit.UIDesignKit';
import { BarToneStore } from '../color/BarToneStore';

/** systemBarStyle 参数（SDK 未导出 SystemBarStyle 类型，本地对齐字段） */
export interface TitleBarSystemBarStyle {
  statusBarContentColor: string;
}

const TITLE_BAR_TRANSPARENT_BACKGROUND: HdsNavigationBackgroundStyle = {
  backgroundColor: $r('sys.color.ohos_id_color_background_transparent')
};

/** 标题栏 / 状态栏前景色：随系统深浅色与页面背景对比度切换 */
export class TitleBarColorHelper {
  /**
   * 沉浸顶格时页面底色为浅/深渐变：
   * - 浅色模式 → 深色前景（返回、标题、状态栏）
   * - 深色模式 → 浅色前景
   */
  static useLightForeground(): boolean {
    return BarToneStore.isDarkMode();
  }

  static buildContentStyle(): HdsTitleBarContentStyle {
    const fg = BarToneStore.resolveForegroundColors(TitleBarColorHelper.useLightForeground());
    return {
      titleStyle: {
        mainTitleColor: fg.barPrimary
      },
      backIconStyle: {
        backgroundColor: Color.Transparent,
        iconColor: fg.barPrimary
      }
    };
  }

  static buildTransparentBackground(): HdsNavigationBackgroundStyle {
    return TITLE_BAR_TRANSPARENT_BACKGROUND;
  }

  static statusBarContentColor(): string {
    return TitleBarColorHelper.useLightForeground() ? '#FFFFFF' : '#000000';
  }

  static buildSystemBarStyle(): TitleBarSystemBarStyle {
    return {
      statusBarContentColor: TitleBarColorHelper.statusBarContentColor()
    };
  }
}
