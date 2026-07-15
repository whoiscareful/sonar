import { PageMap } from './PageMapBuilder';
import { OuterScreenPlayerPage } from './OuterScreenPlayerPage';
import { OuterScreenPreviewFrame } from '../components/debug/OuterScreenPreviewFrame';
import { AuthSession } from '../auth/AuthSession';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PlaybackService } from '../playback/PlaybackService';
import { common } from '@kit.AbilityKit';
import { FloatingTabBar } from '../components/navigation/FloatingTabBar';
import { ScreenProfileStore } from '../ui/adaptation/ScreenProfileStore';
import { OuterScreenPalette, OuterScreenTheme } from '../ui/adaptation/OuterScreenTheme';
import { ImmersiveMaterialHelper } from '../ui/material/ImmersiveMaterialHelper';
import { NavigationPlatform } from '../navigation/NavigationPlatform';
import { UiTokens } from '../ui/tokens/UiTokens';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { HdsPageTitleBar } from '../ui/material/HdsPageTitleBar';
import { TabScrollerBridge } from '../ui/layout/TabScrollerBridge';
import { MusicTabSettingsStore } from '../settings/MusicTabSettingsStore';
import { ProfileAppearanceStore } from '../settings/ProfileAppearanceStore';
import { RecentPlayHistoryStore } from '../settings/RecentPlayHistoryStore';
import { UserPlaylistStore } from '../settings/UserPlaylistStore';
import { PlaylistArtworkStore } from '../settings/PlaylistArtworkStore';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;
const TAG = 'HeartTone.Index';
const BACK_PRESS_INTERVAL: number = 2000;
const SPLASH_MIN_VISIBLE_MS: number = 1600;
const SPLASH_FADE_MS: number = 360;

@Entry
@Component
struct Index {
  @Provide('appPathStack') appPathStack: NavPathStack = new NavPathStack();
  @Provide('tabScrollerBridge') tabScrollerBridge: TabScrollerBridge = new TabScrollerBridge();
  @StorageLink('screenProfile') @Watch('onScreenProfileChange') screenProfile: string = 'standard';
  @StorageLink('outerScreenPreview') @Watch('onScreenProfileChange') outerScreenPreview: boolean = false;
  @StorageLink('currentColorMode') currentColorMode: number = 0;
  @StorageLink('authPhase') authPhase: string = 'booting';
  @StorageLink('rootTabIndex') rootTabIndex: number = 1;
  @State private lastBackPressTime: number = 0;
  @State private showSplash: boolean = true;
  @State private splashOpacity: number = 1;
  private splashStartedAt: number = Date.now();
  aboutToAppear(): void {
    ScreenProfileStore.ensureInitialized();
    ImmersiveMaterialHelper.probeAndCache();
    AppStorage.setOrCreate<number>('rootTabIndex', 1);
    this.tabScrollerBridge.setActiveTab(1);
    ScreenProfileStore.refreshProfile();
    void this.initializeApp();
  }

  private async initializeApp(): Promise<void> {
    try {
      await AuthSession.bootstrap();
      this.maybeRedirectToLogin();
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await MusicTabSettingsStore.getInstance().init(context);
      await ProfileAppearanceStore.getInstance().init(context);
      await RecentPlayHistoryStore.getInstance().init(context);
      await UserPlaylistStore.getInstance().init(context);
      await PlaylistArtworkStore.getInstance().init(context);
      await PlaybackService.initialize(context);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'initializeApp failed: %{public}s', (err as Error).message);
    } finally {
      this.dismissSplashWhenReady();
    }
  }

  private dismissSplashWhenReady(): void {
    const elapsed: number = Date.now() - this.splashStartedAt;
    const delay: number = Math.max(0, SPLASH_MIN_VISIBLE_MS - elapsed);
    setTimeout(() => {
      void this.restoreSystemBars();
      this.getUIContext()?.animateTo(
        { duration: SPLASH_FADE_MS, curve: Curve.EaseOut },
        () => {
          this.splashOpacity = 0;
        }
      );
      setTimeout(() => {
        this.showSplash = false;
      }, SPLASH_FADE_MS);
    }, delay);
  }

  private async restoreSystemBars(): Promise<void> {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const win: window.Window = await window.getLastWindow(context);
      await win.setSpecificSystemBarEnabled('status', true);
      await win.setSpecificSystemBarEnabled('navigationIndicator', true);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'restoreSystemBars failed: %{public}s', (err as Error).message);
    }
  }

  private isOuterUiActive(): boolean {
    return this.outerScreenPreview || this.screenProfile === 'outer';
  }

  private maybeRedirectToLogin(): void {
    if (this.isOuterUiActive()) {
      return;
    }
    if (this.authPhase !== 'anonymous') {
      return;
    }
    this.appPathStack.replacePathByName('LoginPage', null);
  }

  private onScreenProfileChange(): void {
    hilog.info(DOMAIN, TAG, 'uiMode preview=%{public}s profile=%{public}s',
      this.outerScreenPreview ? 'true' : 'false', this.screenProfile);
    if (this.isOuterUiActive()) {
      return;
    }
    this.maybeRedirectToLogin();
  }

  onBackPress(): boolean {
    if (this.outerScreenPreview) {
      ScreenProfileStore.setPreviewEnabled(false);
      return true;
    }
    if (!this.isOuterUiActive() && this.returnLyricsToCover()) {
      return true;
    }
    if (!this.isOuterUiActive() && this.appPathStack.size() > 0) {
      hilog.info(DOMAIN, TAG, 'onBackPress: pop destination, stack size=%{public}d', this.appPathStack.size());
      this.appPathStack.pop();
      return true;
    }
    const now: number = Date.now();
    if (now - this.lastBackPressTime < BACK_PRESS_INTERVAL) {
      hilog.info(DOMAIN, TAG, 'onBackPress: exit app');
      return false;
    }
    this.lastBackPressTime = now;
    hilog.info(DOMAIN, TAG, 'onBackPress: show toast, ask for second press');
    try {
      this.getUIContext().getPromptAction().showToast({ message: '再按一次退出应用', duration: 1500 });
    } catch (_err) {
    }
    return true;
  }

  private returnLyricsToCover(): boolean {
    const pathNames: string[] = this.appPathStack.getAllPathName();
    if (pathNames.length === 0 || pathNames[pathNames.length - 1] !== 'NowPlayingPage') {
      return false;
    }
    const lyricsVisible: boolean = AppStorage.get<boolean>('nowPlayingLyricsVisible') ?? false;
    if (!lyricsVisible) {
      return false;
    }
    AppStorage.setOrCreate<boolean>('nowPlayingLyricsVisible', false);
    return true;
  }

  @Builder
  private buildNavHome() {
    Column() {
      FloatingTabBar()
    }
    .backgroundColor(Color.Transparent)
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildLegacyNavigation() {
    Navigation(this.appPathStack) {
      this.buildNavHome()
    }
    .navDestination(PageMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
    })
  }

  @Builder
  private buildHdsNavigation() {
    HdsNavigation(this.appPathStack) {
      this.buildNavHome()
    }
    .id(`hds-nav-cm-${this.currentColorMode}`)
    .navDestination(PageMap)
    .hideTitleBar(this.appPathStack.size() > 0)
    .titleBar(HdsPageTitleBar.buildPrimary())
    .systemBarStyle(
      HdsPageTitleBar.buildSystemBarOriginalStyle(),
      HdsPageTitleBar.buildSystemBarScrollStyle()
    )
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .bindToScrollable([this.tabScrollerBridge.scrollerForTab(this.rootTabIndex)])
    .mode(NavigationMode.Stack)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
    })
  }

  @Builder
  private buildStandardApp() {
    if (NavigationPlatform.supportsHdsNavigation()) {
      this.buildHdsNavigation()
    } else {
      this.buildLegacyNavigation()
    }
  }

  private outerScreenPalette(): OuterScreenPalette {
    const isDark: boolean = OuterScreenTheme.isDarkUi(this.currentColorMode);
    return OuterScreenTheme.palette(isDark);
  }

  @Builder
  private buildOuterScreenApp() {
    if (this.outerScreenPreview) {
      OuterScreenPreviewFrame()
    } else {
      Column() {
        OuterScreenPlayerPage()
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 160,
        colors: [[this.outerScreenPalette().bgGradientTop, 0], [this.outerScreenPalette().bgGradientBottom, 1]]
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }

  build() {
    Stack() {
      if (this.outerScreenPreview || this.screenProfile === 'outer') {
        this.buildOuterScreenApp()
      } else {
        this.buildStandardApp()
      }

      if (this.showSplash) {
        Image($r('app.media.splash'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.splashOpacity)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .hitTestBehavior(HitTestMode.Block)
          .accessibilityText('HeartTone 正在启动')
      }
    }
    .width('100%')
    .height('100%')
  }
}
