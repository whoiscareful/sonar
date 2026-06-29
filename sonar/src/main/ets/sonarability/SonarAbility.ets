import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { AuthStore } from '../sonar/auth/AuthStore';
import { EndpointRouter } from '../sonar/network/routing/EndpointRouter';
import { PlaybackService } from '../sonar/playback/PlaybackService';
import { ScreenProfileStore } from '../sonar/ui/adaptation/ScreenProfileStore';

const DOMAIN = 0x0000;

export default class SonarAbility extends UIAbility {
  private mainWindow?: window.Window;

  private resolveColorMode(colorMode?: ConfigurationConstant.ColorMode): number {
    if (colorMode === undefined) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    }
    return colorMode;
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    AppStorage.setOrCreate<number>('currentColorMode', this.resolveColorMode(this.context.config.colorMode));
    ScreenProfileStore.ensureInitialized();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    PlaybackService.setContext(this.context);

    // 初始化持久化凭据存储
    AuthStore.getInstance().init(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'AuthStore init failed: %{public}s', err.message);
    });
    void EndpointRouter.init(this.context);
  }

  onDestroy(): void {
    void PlaybackService.release();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('sonar/pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      this.setupImmersiveWindow(windowStage);
    });
  }

  private setupImmersiveWindow(windowStage: window.WindowStage): void {
    try {
      const win: window.Window = windowStage.getMainWindowSync();
      this.mainWindow = win;
      win.setWindowLayoutFullScreen(true).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'setWindowLayoutFullScreen failed: %{public}s', err.message);
      });
      this.applySystemBarStyle(win, this.context.config.colorMode);
      this.updateAvoidAreaInsets(win);
      win.on('avoidAreaChange', () => {
        this.updateAvoidAreaInsets(win);
      });
      ScreenProfileStore.bindWindow(win);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'setupImmersiveWindow failed: %{public}s', JSON.stringify(err));
    }
  }

  private applySystemBarStyle(win: window.Window, colorMode?: ConfigurationConstant.ColorMode): void {
    const isDarkMode: boolean = this.resolveColorMode(colorMode) ===
      ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    win.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: isDarkMode ? '#FFFFFF' : '#000000',
      navigationBarColor: '#00000000',
      navigationBarContentColor: isDarkMode ? '#FFFFFF' : '#000000'
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'setWindowSystemBarProperties failed: %{public}s', err.message);
    });
  }

  private updateAvoidAreaInsets(win: window.Window): void {
    try {
      const density: number = display.getDefaultDisplaySync().densityPixels;
      const topArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const bottomArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const safeDensity: number = density > 0 ? density : 1;
      const topInset: number = topArea.topRect.height / safeDensity;
      const bottomInset: number = bottomArea.bottomRect.height / safeDensity;
      AppStorage.setOrCreate<number>('topRectHeight', topInset);
      AppStorage.setOrCreate<number>('bottomRectHeight', bottomInset);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'updateAvoidAreaInsets failed: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    ScreenProfileStore.unbind();
    // Main window is destroyed, release UI related resources
    this.mainWindow = undefined;
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    AppStorage.setOrCreate<number>('currentColorMode', this.resolveColorMode(newConfig.colorMode));
    if (this.mainWindow !== undefined) {
      this.applySystemBarStyle(this.mainWindow, newConfig.colorMode);
    }
  }

  onForeground(): void {
    // Ability has brought to foreground
    PlaybackService.setContext(this.context);
    if (this.mainWindow !== undefined) {
      this.applySystemBarStyle(this.mainWindow, this.context.config.colorMode);
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    void PlaybackService.flushPersistence();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}