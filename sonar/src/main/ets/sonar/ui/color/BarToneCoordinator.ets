import { BarToneStore } from './BarToneStore';

/** 页签 + miniBar 取色：页签经 barToneUseLightForeground + ResourceColor 瞬时切色；miniBar 由 MiniBarRow 内部 280ms 渐变。 */
@Component
export struct BarToneCoordinator {
  @StorageLink('rootTabIndex') @Watch('onRootTabChange') rootTabIndex: number = 0;
  @StorageLink('barToneUseLightForeground') @Watch('onBarToneChange') barToneUseLightForeground: boolean = false;
  @StorageLink('currentColorMode') @Watch('onColorModeChange') currentColorMode: number = 0;

  private barToneAppliedLight: boolean = false;
  private barToneColorsReady: boolean = false;

  aboutToAppear(): void {
    BarToneStore.ensureInitialized();
    this.applyBarTone();
  }

  private onBarToneChange(): void {
    this.applyBarTone();
  }

  private onColorModeChange(): void {
    this.barToneColorsReady = false;
    BarToneStore.resetBaseline(this.rootTabIndex, BarToneStore.isDarkMode());
  }

  private onRootTabChange(): void {
    this.barToneColorsReady = false;
    BarToneStore.resetBaseline(this.rootTabIndex, BarToneStore.isDarkMode());
  }

  private applyBarTone(): void {
    const useLight: boolean = this.barToneUseLightForeground;
    if (this.barToneColorsReady && useLight === this.barToneAppliedLight) {
      return;
    }

    const next = BarToneStore.resolveForegroundColors(useLight, BarToneStore.isDarkMode());
    this.barToneAppliedLight = useLight;
    BarToneStore.setMiniTargets(next.tabInactive, next.barPrimary, next.barSecondary);
    this.barToneColorsReady = true;
  }

  build() {
    Row()
      .width(0)
      .height(0)
      .visibility(Visibility.None)
  }
}
