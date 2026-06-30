import { LyricsLine } from '../../api/SubsonicTypes';
import { UiTokens } from '../../ui/tokens/UiTokens';

/**
 * 歌词显示组件
 * 支持滚动显示、当前行高亮、平滑动画、点击跳转
 */
@Component
export struct LyricView {
  /** 歌词行数组 */
  @Prop lines: LyricsLine[] = [];
  /** 当前行索引 */
  @Prop @Watch('onCurrentLineIndexChanged') currentLineIndex: number = -1;
  /** 是否显示 */
  @Prop visible: boolean = true;
  /** 组件高度 */
  @Prop viewHeight: number = 200;
  /** 行高 */
  @Prop lineHeight: number = 36;
  /** 当前行字体大小 */
  @Prop activeFontSize: number = 16;
  /** 非当前行字体大小 */
  @Prop inactiveFontSize: number = 14;
  /** 当前行颜色 */
  @Prop activeColor: ResourceColor = UiTokens.COLOR_PRIMARY;
  /** 非当前行颜色 */
  @Prop inactiveColor: ResourceColor = UiTokens.COLOR_TEXT_SECONDARY;
  /** 加载状态 */
  @Prop isLoading: boolean = false;
  /** 是否有歌词 */
  @Prop hasLyrics: boolean = false;
  /** 点击歌词行回调 */
  onLineClick?: (lineIndex: number, timeMs: number) => void;
  /** 是否为全屏模式 */
  @Prop isFullscreen: boolean = false;

  private scroller: Scroller = new Scroller();
  private lastScrolledIndex: number = -2;

  aboutToAppear(): void {
    this.lastScrolledIndex = -2;
  }

  private onCurrentLineIndexChanged(): void {
    setTimeout(() => {
      this.scrollToCurrentLine();
    }, 0);
  }

  private scrollToCurrentLine(): void {
    if (this.currentLineIndex < 0 || this.currentLineIndex >= this.lines.length) {
      return;
    }
    if (this.currentLineIndex === this.lastScrolledIndex) {
      return;
    }
    this.lastScrolledIndex = this.currentLineIndex;
    this.scroller.scrollToIndex(this.currentLineIndex, true, ScrollAlign.CENTER);
  }

  /**
   * 计算行高度
   * 封面模式：紧凑布局（1.2倍）
   * 全屏模式：舒适布局（1.4倍）
   */
  private calculateLineHeight(isActive: boolean, isFiller: boolean): number {
    // 全屏模式 1.4，封面模式 1.2（更紧凑）
    const spacing = this.isFullscreen ? 1.4 : 1.2;
    
    if (isFiller) {
      return Math.ceil(this.inactiveFontSize * spacing);
    }
    
    const fontSize = isActive ? this.activeFontSize : this.inactiveFontSize;
    return Math.max(this.lineHeight, Math.ceil(fontSize * spacing));
  }

  /**
   * 计算透明度（连续渐变，避免阶梯感）
   */
  private calculateOpacity(index: number): number {
    const distance = Math.abs(index - this.currentLineIndex);
    if (distance === 0) {
      return 1.0;
    }
    const minOpacity = this.isFullscreen ? 0.25 : 0.3;
    const fadeRate = this.isFullscreen ? 0.16 : 0.15;
    return Math.max(minOpacity, 1.0 - distance * fadeRate);
  }

  private isFillerLine(text: string): boolean {
    return text === '♪' || text === '〜' || text === '...';
  }

  private handleLineClick(index: number): void {
    if (this.onLineClick && index >= 0 && index < this.lines.length) {
      if (this.isFillerLine(this.lines[index].text)) {
        return;
      }
      this.onLineClick(index, this.lines[index].timeMs);
    }
  }

  @Builder
  private buildEmptyState() {
    Column() {
      if (this.isLoading) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(this.inactiveColor)
        Text('正在加载歌词…')
          .fontSize(this.inactiveFontSize)
          .fontColor(this.inactiveColor)
          .margin({ top: 12 })
      } else if (!this.hasLyrics) {
        Column({ space: 8 }) {
          Text('♪')
            .fontSize(32)
            .fontColor(this.inactiveColor)
            .opacity(0.4)
          Text('暂无歌词')
            .fontSize(this.inactiveFontSize)
            .fontColor(this.inactiveColor)
        }
      }
    }
    .width('100%')
    .height(this.viewHeight)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildLyricLine(line: LyricsLine, index: number) {
    Column() {
      if (this.isFillerLine(line.text)) {
        Text(line.text)
          .fontSize(this.inactiveFontSize * 1.1)
          .fontColor(this.inactiveColor)
          .opacity(0.4)
      } else {
        Text(line.text)
          .fontSize(index === this.currentLineIndex ? this.activeFontSize : this.inactiveFontSize)
          .fontColor(index === this.currentLineIndex ? this.activeColor : this.inactiveColor)
          .fontWeight(index === this.currentLineIndex ? FontWeight.Medium : FontWeight.Normal)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height(this.calculateLineHeight(index === this.currentLineIndex, this.isFillerLine(line.text)))
    .justifyContent(FlexAlign.Center)
    .padding({
      left: this.isFullscreen ? 32 : 20,
      right: this.isFullscreen ? 32 : 20
    })
    .opacity(this.isFillerLine(line.text) ? 0.4 : this.calculateOpacity(index))
    .onClick(() => {
      this.handleLineClick(index);
    })
  }

  build() {
    Column() {
      if (!this.visible) {
        Blank()
          .width(0)
          .height(0)
      } else if (this.lines.length === 0) {
        this.buildEmptyState()
      } else {
        List({ scroller: this.scroller }) {
          ForEach(this.lines, (line: LyricsLine, index: number) => {
            ListItem() {
              this.buildLyricLine(line, index)
            }
          }, (line: LyricsLine, index: number): string => `${index}_${line.timeMs}`)
        }
        .width('100%')
        .height(this.viewHeight)
        .listDirection(Axis.Vertical)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .alignListItem(ListItemAlign.Center)
        .backgroundColor(Color.Transparent)
        .animation({
          duration: 500,
          curve: Curve.FastOutSlowIn
        })
      }
    }
    .width('100%')
    .height(this.viewHeight)
  }
}
