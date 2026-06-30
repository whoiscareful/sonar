import { BarToneColorAnimator } from '../../ui/color/BarToneColorAnimator';
import {
  buildLibraryTabPage,
  buildMusicTabPage,
  buildProfileTabPage
} from './RootTabPages';
import { BarToneStore } from '../../ui/color/BarToneStore';
import { ImmersiveMaterialHelper } from '../../ui/material/ImmersiveMaterialHelper';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { MiniBarRowHost } from './MiniBarRowHost';
import { MINI_BAR_COMPACT_KEY } from './MiniBarStateKeys';
import { TabScrollerBridge } from '../../ui/layout/TabScrollerBridge';
import {
  HdsBarStyle,
  HdsBarWidthRangeOptions,
  HdsTabs,
  HdsTabsBarChangeMode,
  HdsTabsController,
  HdsTabsFloatingStyle,
  HdsTabsMiniBar
} from '@kit.UIDesignKit';

interface RootTabItem {
  pageIndex: number;
  icon: Resource;
  a11yLabel: string;
}

const ROOT_TAB_ITEMS: RootTabItem[] = [
  { pageIndex: 0, icon: $r('app.media.tab_library'), a11yLabel: '音乐' },
  { pageIndex: 1, icon: $r('app.media.tab_album'), a11yLabel: '专辑' },
  { pageIndex: 2, icon: $r('app.media.tab_profile'), a11yLabel: '我的' },
];

const HDS_SIDE_MARGIN_SMALL: number = 16;
const HDS_SIDE_MARGIN_MEDIUM: number = 24;
const HDS_SIDE_MARGIN_LARGE: number = 32;
const WIDTH_BREAKPOINT_MEDIUM: number = 600;
const WIDTH_BREAKPOINT_LARGE: number = 840;
const TAB_TONE_ANIM_MS: number = 280;
/** COLLAPSE 态压缩 label 测量高度，避免换色时 icon 按 icon+label 居中上移（官方 workaround） */
const COLLAPSE_LABEL_FONT_SIZE: number = 0.1;

/**
 * 官方范式：onBarStyleChange 切换两套 BottomTabBarStyle。
 * COLLAPSE 仅更新 iconStyle 配色；labelStyle 固定透明+极小字号，换色不触发表重测。
 */
@Component
export struct HdsTabsShell {
  @Consume('tabScrollerBridge') tabScrollerBridge: TabScrollerBridge = new TabScrollerBridge();
  @StorageLink('rootTabIndex') rootTabIndex: number = 0;
  @StorageProp('bottomRectHeight') @Watch('onLayoutDepsChange') bottomInset: number = 0;
  @StorageLink('barToneUseLightForeground') @Watch('onBarToneFlip') barToneUseLightForeground: boolean = false;
  @Prop @Watch('onLayoutDepsChange') containerWidth: number = 360;

  @State private tabBarCompact: boolean = false;
  @State private tabInactiveHex: string = '#282A32';
  @State private tabSelectedHex: string = '#7B6BA8';
  @State private tabIconInactiveHex: string = '#282A32';
  @State private tabIconSelectedHex: string = '#7B6BA8';
  @State private cachedFloatingStyle: HdsTabsFloatingStyle | undefined = undefined;

  private hdsTabsController: HdsTabsController = new HdsTabsController();
  private tabColorAnimator: BarToneColorAnimator = new BarToneColorAnimator();
  private tabSelectedColorAnimator: BarToneColorAnimator = new BarToneColorAnimator();
  private tabToneReady: boolean = false;
  private lastSideMargin: number = HDS_SIDE_MARGIN_SMALL;
  private lastBottomMargin: number = UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN;
  private lastBarWidth: HdsBarWidthRangeOptions = {
    smallWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_SMALL,
    mediumWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_MEDIUM,
    largeWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_LARGE
  };

  aboutToAppear(): void {
    AppStorage.setOrCreate<boolean>(MINI_BAR_COMPACT_KEY, true);
    this.applyTabTone(false);
    this.refreshFloatingStyle(true);
  }

  aboutToDisappear(): void {
    this.tabColorAnimator.stop();
    this.tabSelectedColorAnimator.stop();
  }

  private onLayoutDepsChange(): void {
    this.refreshFloatingStyle(false);
  }

  private onBarToneFlip(): void {
    this.applyTabTone(true);
  }

  private resolveTargetInactiveHex(): string {
    return BarToneStore.resolveForegroundColors(this.barToneUseLightForeground, BarToneStore.isDarkMode())
      .tabInactive;
  }

  private resolveTargetSelectedHex(): string {
    return BarToneStore.resolveForegroundColors(this.barToneUseLightForeground, BarToneStore.isDarkMode())
      .tabSelected;
  }

  private applyTabTone(animated: boolean): void {
    const targetInactive: string = this.resolveTargetInactiveHex();
    const targetSelected: string = this.resolveTargetSelectedHex();
    if (this.tabBarCompact) {
      this.tabColorAnimator.stop();
      this.tabSelectedColorAnimator.stop();
      this.tabIconInactiveHex = targetInactive;
      this.tabIconSelectedHex = targetSelected;
      this.tabToneReady = true;
      return;
    }
    const shouldAnimate: boolean = animated && this.tabToneReady;
    if (shouldAnimate) {
      this.tabColorAnimator.animateHex(
        this.tabInactiveHex,
        targetInactive,
        TAB_TONE_ANIM_MS,
        (value: string) => {
          this.tabInactiveHex = value;
        }
      );
      this.tabSelectedColorAnimator.animateHex(
        this.tabSelectedHex,
        targetSelected,
        TAB_TONE_ANIM_MS,
        (value: string) => {
          this.tabSelectedHex = value;
        }
      );
    } else {
      this.tabColorAnimator.stop();
      this.tabSelectedColorAnimator.stop();
      this.tabInactiveHex = targetInactive;
      this.tabSelectedHex = targetSelected;
    }
    this.tabToneReady = true;
  }

  private onBarStyleChange(
    miniBarStyle: HdsBarStyle,
    tabBarStyle: HdsBarStyle,
    _miniBarWidth: number,
    _tabBarWidth: number,
    _mode: HdsTabsBarChangeMode
  ): void {
    AppStorage.setOrCreate<boolean>(MINI_BAR_COMPACT_KEY, miniBarStyle === HdsBarStyle.COLLAPSE);

    const compact: boolean = tabBarStyle === HdsBarStyle.COLLAPSE;
    if (compact === this.tabBarCompact) {
      return;
    }
    this.tabColorAnimator.stop();
    this.tabSelectedColorAnimator.stop();
    const targetInactive: string = this.resolveTargetInactiveHex();
    const targetSelected: string = this.resolveTargetSelectedHex();
    this.tabBarCompact = compact;
    if (compact) {
      this.tabIconInactiveHex = targetInactive;
      this.tabIconSelectedHex = targetSelected;
    } else {
      this.tabInactiveHex = targetInactive;
      this.tabSelectedHex = targetSelected;
    }
  }

  private buildCompactTabBarStyle(item: RootTabItem): BottomTabBarStyle {
    return new BottomTabBarStyle(item.icon, item.a11yLabel)
      .labelStyle({
        selectedColor: Color.Transparent,
        unselectedColor: Color.Transparent,
        font: {
          size: COLLAPSE_LABEL_FONT_SIZE,
          weight: FontWeight.Normal
        }
      })
      .iconStyle({
        selectedColor: this.tabIconSelectedHex,
        unselectedColor: this.tabIconInactiveHex
      });
  }

  private buildExpandedTabBarStyle(item: RootTabItem): BottomTabBarStyle {
    return new BottomTabBarStyle(item.icon, item.a11yLabel)
      .labelStyle({
        selectedColor: this.tabSelectedHex,
        unselectedColor: this.tabInactiveHex,
        font: {
          size: 10,
          weight: FontWeight.Medium
        }
      })
      .iconStyle({
        selectedColor: this.tabSelectedHex,
        unselectedColor: this.tabInactiveHex
      });
  }

  private buildHdsTabBarStyle(item: RootTabItem): BottomTabBarStyle {
    if (this.tabBarCompact) {
      return this.buildCompactTabBarStyle(item);
    }
    return this.buildExpandedTabBarStyle(item);
  }

  private resolveSideMargin(): number {
    if (this.containerWidth >= WIDTH_BREAKPOINT_LARGE) {
      return HDS_SIDE_MARGIN_LARGE;
    }
    if (this.containerWidth >= WIDTH_BREAKPOINT_MEDIUM) {
      return HDS_SIDE_MARGIN_MEDIUM;
    }
    return HDS_SIDE_MARGIN_SMALL;
  }

  private resolveFloatingBarWidth(): HdsBarWidthRangeOptions {
    return {
      smallWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_SMALL,
      mediumWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_MEDIUM,
      largeWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_LARGE
    };
  }

  @Builder
  private miniBarBuilder() {
    MiniBarRowHost()
  }

  private buildFloatingStyle(sideMargin: number, bottomMargin: number): HdsTabsFloatingStyle {
    const miniBar: HdsTabsMiniBar = {
      miniBarBuilder: () => {
        this.miniBarBuilder();
      },
      onBarStyleChange: (
        miniBarStyle: HdsBarStyle,
        tabBarStyle: HdsBarStyle,
        miniBarWidth: number,
        tabBarWidth: number,
        mode: HdsTabsBarChangeMode
      ) => {
        this.onBarStyleChange(miniBarStyle, tabBarStyle, miniBarWidth, tabBarWidth, mode);
      }
    };
    return {
      barWidth: this.resolveFloatingBarWidth(),
      barBottomMargin: bottomMargin,
      barSideMargin: sideMargin,
      gradientMask: {
        maskColor: UiTokens.COLOR_OVERLAY_SCRIM,
        maskHeight: UiTokens.FLOATING_TAB_BAR_HEIGHT + UiTokens.FLOATING_TAB_GRADIENT_MASK_EXTRA
      },
      systemMaterialEffect: ImmersiveMaterialHelper.buildNavigationEffect(),
      miniBar: miniBar
    };
  }

  private refreshFloatingStyle(force: boolean): void {
    const sideMargin: number = this.resolveSideMargin();
    const barWidth: HdsBarWidthRangeOptions = this.resolveFloatingBarWidth();
    const bottomMargin: number = UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + this.bottomInset;
    if (!force &&
      this.cachedFloatingStyle !== undefined &&
      sideMargin === this.lastSideMargin &&
      bottomMargin === this.lastBottomMargin &&
      barWidth.smallWidth === this.lastBarWidth.smallWidth &&
      barWidth.mediumWidth === this.lastBarWidth.mediumWidth &&
      barWidth.largeWidth === this.lastBarWidth.largeWidth) {
      return;
    }
    this.lastSideMargin = sideMargin;
    this.lastBottomMargin = bottomMargin;
    this.lastBarWidth = barWidth;
    this.cachedFloatingStyle = this.buildFloatingStyle(sideMargin, bottomMargin);
  }

  private resolveBarFloatingStyle(): HdsTabsFloatingStyle {
    if (this.cachedFloatingStyle !== undefined) {
      return this.cachedFloatingStyle;
    }
    return this.buildFloatingStyle(this.resolveSideMargin(),
      UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + this.bottomInset);
  }

  build() {
    HdsTabs({ controller: this.hdsTabsController, index: this.rootTabIndex }) {
      TabContent() {
        buildMusicTabPage()
      }
      .tabBar(this.buildHdsTabBarStyle(ROOT_TAB_ITEMS[0]))

      TabContent() {
        buildLibraryTabPage()
      }
      .tabBar(this.buildHdsTabBarStyle(ROOT_TAB_ITEMS[1]))

      TabContent() {
        buildProfileTabPage()
      }
      .tabBar(this.buildHdsTabBarStyle(ROOT_TAB_ITEMS[2]))
    }
    .barOverlap(true)
    .barPosition(BarPosition.End)
    .barMode(BarMode.Fixed)
    .vertical(false)
    .scrollable(false)
    .animationDuration(0)
    .barFloatingStyle(this.resolveBarFloatingStyle())
    .onTabBarClick((index: number) => {
      this.tabScrollerBridge.handleTabBarClick(index, this.rootTabIndex);
    })
    .onChange((index: number) => {
      this.rootTabIndex = index;
      this.tabScrollerBridge.setActiveTab(index);
    })
    .width('100%')
    .height('100%')
  }
}
