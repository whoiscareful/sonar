/** Tab 根页 Scroller 注册表，供 HdsNavigation.bindToScrollable 绑定当前 Tab */
@Observed
export class TabScrollerBridge {
  private static readonly DOUBLE_TAP_INTERVAL_MS: number = 350;

  private scrollers: ListScroller[] = [new ListScroller(), new ListScroller(), new ListScroller()];
  activeTabIndex: number = 0;
  private lastTabBarTapIndex: number = -1;
  private lastTabBarTapAt: number = 0;

  scrollerForTab(tabIndex: number): ListScroller {
    if (tabIndex >= 0 && tabIndex < this.scrollers.length) {
      return this.scrollers[tabIndex];
    }
    return this.scrollers[0];
  }

  setActiveTab(tabIndex: number): void {
    if (tabIndex >= 0 && tabIndex < this.scrollers.length) {
      this.activeTabIndex = tabIndex;
    }
  }

  activeScroller(): Scroller {
    return this.scrollers[this.activeTabIndex];
  }

  scrollMusicToSong(indexInGroup: number): void {
    if (indexInGroup < 0) {
      return;
    }
    try {
      this.scrollers[0].scrollToItemInGroup(0, indexInGroup, true, ScrollAlign.CENTER);
    } catch (_err) {
      // 列表尚未完成布局时不定位，避免可选快捷动作影响主列表。
    }
  }

  /** 音乐(0) / 首页(1) Tab 已选中时双击 TabBar 图标回到列表顶部 */
  handleTabBarClick(clickedIndex: number, currentIndex: number): void {
    if (!TabScrollerBridge.supportsScrollToTop(clickedIndex)) {
      return;
    }
    if (clickedIndex !== currentIndex) {
      this.lastTabBarTapIndex = clickedIndex;
      this.lastTabBarTapAt = Date.now();
      return;
    }
    const now: number = Date.now();
    if (this.lastTabBarTapIndex === clickedIndex &&
      now - this.lastTabBarTapAt <= TabScrollerBridge.DOUBLE_TAP_INTERVAL_MS) {
      this.scrollTabToTop(clickedIndex);
      this.lastTabBarTapIndex = -1;
      this.lastTabBarTapAt = 0;
      return;
    }
    this.lastTabBarTapIndex = clickedIndex;
    this.lastTabBarTapAt = now;
  }

  scrollTabToTop(tabIndex: number): void {
    if (!TabScrollerBridge.supportsScrollToTop(tabIndex)) {
      return;
    }
    const scroller: Scroller = this.scrollerForTab(tabIndex);
    scroller.scrollTo({
      xOffset: 0,
      yOffset: 0,
      animation: { duration: 280, curve: Curve.EaseOut }
    });
  }

  private static supportsScrollToTop(tabIndex: number): boolean {
    return tabIndex === 0 || tabIndex === 1;
  }
}
