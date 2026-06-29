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
import { RecentPlayHistoryStore } from '../settings/RecentPlayHistoryStore';

const DOMAIN = 0x0000;
const TAG = 'Sonar.Index';
const BACK_PRESS_INTERVAL: number = 2000;

@Entry
@Component
struct Index {
  @Provide('appPathStack') appPathStack: NavPathStack = new NavPathStack();
  @Provide('tabScrollerBridge') tabScrollerBridge: TabScrollerBridge = new TabScrollerBridge();
  @StorageLink('screenProfile') @Watch('onScreenProfileChange') screenProfile: string = 'standard';
  @StorageLink('outerScreenPreview') @Watch('onScreenProfileChange') outerScreenPreview: boolean = false;
  @StorageLink('currentColorMode') currentColorMode: number = 0;
  @StorageLink('authPhase') authPhase: string = 'booting';
  @StorageLink('rootTabIndex') rootTabIndex: number = 0;
  @State private lastBackPressTime: number = 0;

  async aboutToAppear(): Promise<void> {
    ScreenProfileStore.ensureInitialized();
    ImmersiveMaterialHelper.probeAndCache();
    await AuthSession.bootstrap();
    AppStorage.setOrCreate<number>('rootTabIndex', 0);
    this.tabScrollerBridge.setActiveTab(0);
    ScreenProfileStore.refreshProfile();
    this.maybeRedirectToLogin();
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await MusicTabSettingsStore.getInstance().init(context);
    await RecentPlayHistoryStore.getInstance().init(context);
    await PlaybackService.initialize(context);
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
    if (this.outerScreenPreview || this.screenProfile === 'outer') {
      this.buildOuterScreenApp()
    } else {
      this.buildStandardApp()
    }
  }
}
