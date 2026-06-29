import { display, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UiTokens } from '../tokens/UiTokens';

export type ScreenProfile = 'outer' | 'standard';

const STORAGE_KEY: string = 'screenProfile';
const PREVIEW_KEY: string = 'outerScreenPreview';
const DOMAIN: number = 0x0000;
const TAG: string = 'Sonar.ScreenProfile';

interface WindowVpSize {
  widthVp: number;
  heightVp: number;
}

interface FoldSnapshot {
  foldable: boolean;
  mode: display.FoldDisplayMode;
  status: display.FoldStatus;
}

export class ScreenProfileStore {
  private static boundWindow?: window.Window;
  private static displayListener?: (id: number) => void;
  private static windowSizeListener?: (size: window.Size) => void;
  private static foldDisplayModeListener?: (mode: display.FoldDisplayMode) => void;
  private static foldStatusListener?: (status: display.FoldStatus) => void;
  private static retryTimerId: number = -1;

  static ensureInitialized(): void {
    AppStorage.setOrCreate<string>(STORAGE_KEY, 'standard');
    AppStorage.setOrCreate<boolean>(PREVIEW_KEY, false);
  }

  static setPreviewEnabled(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(PREVIEW_KEY, enabled);
    if (enabled) {
      AppStorage.setOrCreate<string>(STORAGE_KEY, 'outer');
      hilog.info(DOMAIN, TAG, 'preview enabled');
      return;
    }
    hilog.info(DOMAIN, TAG, 'preview disabled');
    ScreenProfileStore.refreshProfile();
  }

  static bindWindow(win: window.Window): void {
    ScreenProfileStore.ensureInitialized();
    ScreenProfileStore.unbind();
    ScreenProfileStore.boundWindow = win;

    ScreenProfileStore.windowSizeListener = (_size: window.Size) => {
      ScreenProfileStore.refreshProfile();
    };
    try {
      win.on('windowSizeChange', ScreenProfileStore.windowSizeListener);
    } catch (_err) {
    }

    ScreenProfileStore.displayListener = (_id: number) => {
      ScreenProfileStore.refreshProfile();
    };
    ScreenProfileStore.registerDisplayListener('change', ScreenProfileStore.displayListener);

    ScreenProfileStore.foldDisplayModeListener = (_mode: display.FoldDisplayMode) => {
      ScreenProfileStore.scheduleRefresh(0);
    };
    ScreenProfileStore.registerDisplayListener('foldDisplayModeChange',
      ScreenProfileStore.foldDisplayModeListener);

    ScreenProfileStore.foldStatusListener = (_status: display.FoldStatus) => {
      ScreenProfileStore.scheduleRefresh(0);
    };
    ScreenProfileStore.registerDisplayListener('foldStatusChange', ScreenProfileStore.foldStatusListener);

    ScreenProfileStore.refreshProfile();
    ScreenProfileStore.scheduleRefresh(120);
    ScreenProfileStore.scheduleRefresh(480);
  }

  static unbind(): void {
    ScreenProfileStore.clearRetryTimer();
    if (ScreenProfileStore.boundWindow !== undefined && ScreenProfileStore.windowSizeListener !== undefined) {
      try {
        ScreenProfileStore.boundWindow.off('windowSizeChange', ScreenProfileStore.windowSizeListener);
      } catch (_err) {
      }
    }
    ScreenProfileStore.unregisterDisplayListener('change', ScreenProfileStore.displayListener);
    ScreenProfileStore.unregisterDisplayListener('foldDisplayModeChange',
      ScreenProfileStore.foldDisplayModeListener);
    ScreenProfileStore.unregisterDisplayListener('foldStatusChange', ScreenProfileStore.foldStatusListener);
    ScreenProfileStore.boundWindow = undefined;
    ScreenProfileStore.windowSizeListener = undefined;
    ScreenProfileStore.displayListener = undefined;
    ScreenProfileStore.foldDisplayModeListener = undefined;
    ScreenProfileStore.foldStatusListener = undefined;
  }

  static refreshProfile(): void {
    if (AppStorage.get<boolean>(PREVIEW_KEY) === true) {
      AppStorage.setOrCreate<string>(STORAGE_KEY, 'outer');
      return;
    }
    try {
      AppStorage.setOrCreate<string>(STORAGE_KEY, ScreenProfileStore.resolveProfile());
    } catch (_err) {
      AppStorage.setOrCreate<string>(STORAGE_KEY, 'standard');
    }
  }

  static resolveProfile(): ScreenProfile {
    const profile: ScreenProfile = ScreenProfileStore.computeProfile();
    const snap: FoldSnapshot = ScreenProfileStore.readFoldSnapshot();
    const size: WindowVpSize = ScreenProfileStore.readWindowVp();
    hilog.info(
      DOMAIN,
      TAG,
      'foldable=%{public}s mode=%{public}d status=%{public}d size=%{public}.1fx%{public}.1fvp -> %{public}s',
      snap.foldable ? 'true' : 'false',
      snap.mode,
      snap.status,
      size.widthVp,
      size.heightVp,
      profile
    );
    return profile;
  }

  private static computeProfile(): ScreenProfile {
    const snap: FoldSnapshot = ScreenProfileStore.readFoldSnapshot();
    const size: WindowVpSize = ScreenProfileStore.readWindowVp();

    if (snap.foldable) {
      if (snap.mode === display.FoldDisplayMode.FOLD_DISPLAY_MODE_SUB) {
        return 'outer';
      }
      if (snap.mode === display.FoldDisplayMode.FOLD_DISPLAY_MODE_FULL &&
        snap.status === display.FoldStatus.FOLD_STATUS_EXPANDED) {
        return 'standard';
      }
      if (snap.mode === display.FoldDisplayMode.FOLD_DISPLAY_MODE_MAIN &&
        snap.status !== display.FoldStatus.FOLD_STATUS_EXPANDED) {
        return 'outer';
      }
      if (snap.status === display.FoldStatus.FOLD_STATUS_FOLDED &&
        snap.mode !== display.FoldDisplayMode.FOLD_DISPLAY_MODE_FULL) {
        return 'outer';
      }
    }

    if (ScreenProfileStore.looksLikeCoverWindow(size.widthVp, size.heightVp)) {
      return 'outer';
    }
    return 'standard';
  }

  private static readFoldSnapshot(): FoldSnapshot {
    try {
      return {
        foldable: display.isFoldable(),
        mode: display.getFoldDisplayMode(),
        status: display.getFoldStatus()
      };
    } catch (_err) {
      return {
        foldable: false,
        mode: display.FoldDisplayMode.FOLD_DISPLAY_MODE_UNKNOWN,
        status: display.FoldStatus.FOLD_STATUS_UNKNOWN
      };
    }
  }

  private static looksLikeCoverWindow(widthVp: number, heightVp: number): boolean {
    if (widthVp <= 0 || heightVp <= 0) {
      return false;
    }
    const minEdge: number = Math.min(widthVp, heightVp);
    const maxEdge: number = Math.max(widthVp, heightVp);
    const ratio: number = widthVp / heightVp;

    const isSquareCover: boolean = ratio >= UiTokens.OUTER_SCREEN_ASPECT_RATIO_MIN &&
      ratio <= UiTokens.OUTER_SCREEN_ASPECT_RATIO_MAX &&
      minEdge < UiTokens.OUTER_SCREEN_MAX_COMPACT_EDGE;

    const isWideCover: boolean = minEdge >= 280 && minEdge < UiTokens.OUTER_SCREEN_MAX_COMPACT_EDGE &&
      maxEdge < 680 && ratio > 1.2;

    return isSquareCover || isWideCover;
  }

  private static readWindowVp(): WindowVpSize {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      const density: number = d.densityPixels > 0 ? d.densityPixels : 1;
      return {
        widthVp: d.width / density,
        heightVp: d.height / density
      };
    } catch (_err) {
      return { widthVp: 0, heightVp: 0 };
    }
  }

  private static registerDisplayListener(event: string, listener: object | undefined): void {
    if (listener === undefined) {
      return;
    }
    try {
      if (event === 'change') {
        display.on('change', listener as (id: number) => void);
      } else if (event === 'foldDisplayModeChange') {
        display.on('foldDisplayModeChange', listener as (mode: display.FoldDisplayMode) => void);
      } else if (event === 'foldStatusChange') {
        display.on('foldStatusChange', listener as (status: display.FoldStatus) => void);
      }
    } catch (_err) {
    }
  }

  private static unregisterDisplayListener(event: string, listener: object | undefined): void {
    if (listener === undefined) {
      return;
    }
    try {
      if (event === 'change') {
        display.off('change', listener as (id: number) => void);
      } else if (event === 'foldDisplayModeChange') {
        display.off('foldDisplayModeChange', listener as (mode: display.FoldDisplayMode) => void);
      } else if (event === 'foldStatusChange') {
        display.off('foldStatusChange', listener as (status: display.FoldStatus) => void);
      }
    } catch (_err) {
    }
  }

  private static scheduleRefresh(delayMs: number): void {
    if (delayMs <= 0) {
      ScreenProfileStore.refreshProfile();
      return;
    }
    ScreenProfileStore.clearRetryTimer();
    ScreenProfileStore.retryTimerId = setTimeout(() => {
      ScreenProfileStore.retryTimerId = -1;
      ScreenProfileStore.refreshProfile();
    }, delayMs);
  }

  private static clearRetryTimer(): void {
    if (ScreenProfileStore.retryTimerId < 0) {
      return;
    }
    clearTimeout(ScreenProfileStore.retryTimerId);
    ScreenProfileStore.retryTimerId = -1;
  }
}
