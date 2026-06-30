import {
  HdsNavigationTitleBarOptions,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { ImmersiveMaterialHelper } from './ImmersiveMaterialHelper';
import { TitleBarColorHelper, TitleBarSystemBarStyle } from './TitleBarColorHelper';

/** 全站 HDS 标题栏：对齐官方 IMMERSIVE_GRADIENT_BLUR + systemMaterialEffect */
export class HdsPageTitleBar {
  static buildTitleBarStyle(): TitleBarStyleOptions {
    return {
      scrollEffectOpts: {
        scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
      },
      systemMaterialEffect: ImmersiveMaterialHelper.buildTitleBarEffect()
    };
  }

  /** 状态栏前景色（静止态） */
  static buildSystemBarOriginalStyle(): TitleBarSystemBarStyle {
    return TitleBarColorHelper.buildSystemBarStyle();
  }

  /** 状态栏前景色（滚动模糊态） */
  static buildSystemBarScrollStyle(): TitleBarSystemBarStyle {
    return TitleBarColorHelper.buildSystemBarStyle();
  }

  /** Tab 根页：空标题栏（无返回、无标题） */
  static buildPrimary(): HdsNavigationTitleBarOptions {
    return {
      style: HdsPageTitleBar.buildTitleBarStyle()
    };
  }

  /** 二级页：返回 + 标题（ignoreLayoutSafeArea 下须避让状态栏） */
  static buildSecondary(mainTitle: string): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      style: HdsPageTitleBar.buildTitleBarStyle(),
      content: {
        title: {
          mainTitle: mainTitle
        },
        backIcon: {
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true
        }
      }
    };
  }
}
