import { ConfigurationConstant } from '@kit.AbilityKit';

import { BarToneStore } from '../color/BarToneStore';
import { UiTokens } from '../tokens/UiTokens';

export interface OuterScreenPalette {
  bgGradientTop: string;
  bgGradientBottom: string;
  bezel: string;
  progressTrack: string;
  progressFill: string;
  progressThumb: string;
  idleCoverIcon: ResourceColor;
}

export class OuterScreenTheme {
  static isDarkUi(colorMode: number): boolean {
    if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      return true;
    }
    if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      return false;
    }
    return BarToneStore.isDarkMode();
  }

  static palette(isDark: boolean): OuterScreenPalette {
    if (isDark) {
      return {
        bgGradientTop: UiTokens.OUTER_SCREEN_BG_GRADIENT_TOP_DARK,
        bgGradientBottom: UiTokens.OUTER_SCREEN_BG_GRADIENT_BOTTOM_DARK,
        bezel: UiTokens.OUTER_SCREEN_BEZEL_DARK,
        progressTrack: UiTokens.OUTER_SCREEN_PROGRESS_TRACK_DARK,
        progressFill: UiTokens.OUTER_SCREEN_PROGRESS_FILL_DARK,
        progressThumb: UiTokens.OUTER_SCREEN_PROGRESS_THUMB_DARK,
        idleCoverIcon: UiTokens.COLOR_TAB_ICON_INACTIVE_ON_DARK_BG
      };
    }
    return {
      bgGradientTop: UiTokens.OUTER_SCREEN_BG_GRADIENT_TOP_LIGHT,
      bgGradientBottom: UiTokens.OUTER_SCREEN_BG_GRADIENT_BOTTOM_LIGHT,
      bezel: UiTokens.OUTER_SCREEN_BEZEL_LIGHT,
      progressTrack: UiTokens.OUTER_SCREEN_PROGRESS_TRACK_LIGHT,
      progressFill: UiTokens.OUTER_SCREEN_PROGRESS_FILL_LIGHT,
      progressThumb: UiTokens.OUTER_SCREEN_PROGRESS_THUMB_LIGHT,
      idleCoverIcon: UiTokens.COLOR_TAB_ICON_INACTIVE_ON_LIGHT_BG
    };
  }
}
