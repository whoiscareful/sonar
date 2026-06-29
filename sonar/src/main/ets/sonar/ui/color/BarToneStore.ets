import { ConfigurationConstant } from '@kit.AbilityKit';

import { ColorUtil } from './ColorUtil';

const BAR_TONE_USE_LIGHT_KEY: string = 'barToneUseLightForeground';
const BAR_TONE_SAMPLE_HEX_KEY: string = 'barToneSampleHex';

export const BAR_TONE_TAB_INACTIVE_KEY: string = 'barToneTabInactiveDisplay';
export const BAR_TONE_MINI_TARGET_INACTIVE_KEY: string = 'barToneMiniTargetInactive';
export const BAR_TONE_MINI_TARGET_PRIMARY_KEY: string = 'barToneMiniTargetPrimary';
export const BAR_TONE_MINI_TARGET_SECONDARY_KEY: string = 'barToneMiniTargetSecondary';

const GRADIENT_TOP_LIGHT: string = '#F7F9FC';
const GRADIENT_BOTTOM_LIGHT: string = '#EEF2F7';
const GRADIENT_TOP_DARK: string = '#21222B';
const GRADIENT_BOTTOM_DARK: string = '#121317';
const BAR_POSITION_RATIO: number = 0.85;

interface BarTonePalettePair {
  onLightBg: string;
  onDarkBg: string;
}

interface BarToneThemePalette {
  inactive: BarTonePalettePair;
  brandPrimary: BarTonePalettePair;
  primary: BarTonePalettePair;
  secondary: BarTonePalettePair;
}

export interface BarToneForegroundColors {
  tabInactive: string;
  tabSelected: string;
  barPrimary: string;
  barSecondary: string;
}

export class BarToneStore {
  static ensureInitialized(): void {
    if (AppStorage.get<boolean>(BAR_TONE_USE_LIGHT_KEY) === undefined) {
      AppStorage.setOrCreate<boolean>(BAR_TONE_USE_LIGHT_KEY, false);
    }
    if (AppStorage.get<string>(BAR_TONE_SAMPLE_HEX_KEY) === undefined) {
      AppStorage.setOrCreate<string>(BAR_TONE_SAMPLE_HEX_KEY, GRADIENT_BOTTOM_LIGHT);
    }
    if (AppStorage.get<string>(BAR_TONE_TAB_INACTIVE_KEY) === undefined) {
      AppStorage.setOrCreate<string>(BAR_TONE_TAB_INACTIVE_KEY, '#282A32');
    }
    if (AppStorage.get<string>(BAR_TONE_MINI_TARGET_INACTIVE_KEY) === undefined) {
      AppStorage.setOrCreate<string>(BAR_TONE_MINI_TARGET_INACTIVE_KEY, '#282A32');
    }
    if (AppStorage.get<string>(BAR_TONE_MINI_TARGET_PRIMARY_KEY) === undefined) {
      AppStorage.setOrCreate<string>(BAR_TONE_MINI_TARGET_PRIMARY_KEY, '#1B1D23');
    }
    if (AppStorage.get<string>(BAR_TONE_MINI_TARGET_SECONDARY_KEY) === undefined) {
      AppStorage.setOrCreate<string>(BAR_TONE_MINI_TARGET_SECONDARY_KEY, '#3C3F4A');
    }
  }

  static isDarkMode(): boolean {
    const mode: number = AppStorage.get<number>('currentColorMode') ??
      ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    return mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  private static themePalette(isDarkMode: boolean): BarToneThemePalette {
    const brandPrimary: BarTonePalettePair = { onLightBg: '#7B6BA8', onDarkBg: '#B8AAD4' };
    if (isDarkMode) {
      const inactive: BarTonePalettePair = { onLightBg: '#282A32', onDarkBg: '#EBEBF5' };
      const primary: BarTonePalettePair = { onLightBg: '#1B1D23', onDarkBg: '#F2F3F5' };
      const secondary: BarTonePalettePair = { onLightBg: '#3C3F4A', onDarkBg: '#EBEBF5' };
      return { inactive: inactive, brandPrimary: brandPrimary, primary: primary, secondary: secondary };
    }
    const inactiveLight: BarTonePalettePair = { onLightBg: '#282A32', onDarkBg: '#FFFFFF' };
    const primaryLight: BarTonePalettePair = { onLightBg: '#1B1D23', onDarkBg: '#F2F3F5' };
    const secondaryLight: BarTonePalettePair = { onLightBg: '#3C3F4A', onDarkBg: '#EBEBF5' };
    return {
      inactive: inactiveLight,
      brandPrimary: brandPrimary,
      primary: primaryLight,
      secondary: secondaryLight
    };
  }

  static resolveForegroundColors(useLightForeground: boolean, isDarkMode?: boolean): BarToneForegroundColors {
    const palette: BarToneThemePalette = BarToneStore.themePalette(isDarkMode ?? BarToneStore.isDarkMode());
    if (useLightForeground) {
      return {
        tabInactive: palette.inactive.onDarkBg,
        tabSelected: palette.brandPrimary.onDarkBg,
        barPrimary: palette.primary.onDarkBg,
        barSecondary: palette.secondary.onDarkBg
      };
    }
    return {
      tabInactive: palette.inactive.onLightBg,
      tabSelected: palette.brandPrimary.onLightBg,
      barPrimary: palette.primary.onLightBg,
      barSecondary: palette.secondary.onLightBg
    };
  }

  static setMiniTargets(inactive: string, primary: string, secondary: string): void {
    AppStorage.set<string>(BAR_TONE_MINI_TARGET_INACTIVE_KEY, inactive);
    AppStorage.set<string>(BAR_TONE_MINI_TARGET_PRIMARY_KEY, primary);
    AppStorage.set<string>(BAR_TONE_MINI_TARGET_SECONDARY_KEY, secondary);
  }

  static setTabInactiveDisplay(color: string): void {
    const current: string | undefined = AppStorage.get<string>(BAR_TONE_TAB_INACTIVE_KEY);
    if (current === color) {
      return;
    }
    AppStorage.set<string>(BAR_TONE_TAB_INACTIVE_KEY, color);
  }

  static getTabInactiveDisplay(): string {
    return AppStorage.get<string>(BAR_TONE_TAB_INACTIVE_KEY) ?? '#282A32';
  }

  private static baselineSampleHex(_tabIndex: number, isDarkMode: boolean): string {
    if (isDarkMode) {
      return ColorUtil.blendHex(GRADIENT_TOP_DARK, GRADIENT_BOTTOM_DARK, BAR_POSITION_RATIO);
    }
    return ColorUtil.blendHex(GRADIENT_TOP_LIGHT, GRADIENT_BOTTOM_LIGHT, BAR_POSITION_RATIO);
  }

  private static applySample(hex: string): void {
    const useLight: boolean = ColorUtil.isDarkBackground(hex);
    AppStorage.set<boolean>(BAR_TONE_USE_LIGHT_KEY, useLight);
    AppStorage.set<string>(BAR_TONE_SAMPLE_HEX_KEY, hex);
  }

  static resetBaseline(tabIndex: number, isDarkMode?: boolean): void {
    BarToneStore.ensureInitialized();
    const dark: boolean = isDarkMode ?? BarToneStore.isDarkMode();
    const hex: string = BarToneStore.baselineSampleHex(tabIndex, dark);
    BarToneStore.applySample(hex);
  }

  static reportBottomSample(hex: string): void {
    BarToneStore.ensureInitialized();
    BarToneStore.applySample(hex);
  }
}
