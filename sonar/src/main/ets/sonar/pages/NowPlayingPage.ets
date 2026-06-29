import { OuterScreenCoverStack } from '../components/playback/OuterScreenCoverStack';
import { OuterScreenProgressBar } from '../components/playback/OuterScreenProgressBar';
import { LyricView } from '../components/lyrics/LyricView';
import { LyricViewModel } from '../viewmodel/LyricViewModel';
import { PlaybackSnapshot, PlaybackMode } from '../playback/PlaybackSnapshot';
import { PlaybackService } from '../playback/PlaybackService';
import { UiTokens } from '../ui/tokens/UiTokens';
import { AuthStore } from '../auth/AuthStore';
import { ToastUtil } from '../common/ToastUtil';
import { PlaylistSheetOpener } from '../components/playlist/PlaylistSheetOpener';

/**
 * 播放详情页
 * 支持两种模式：封面模式（默认）和全屏歌词模式
 */
@Component
export struct NowPlayingPage {
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @StorageLink('playback') @Watch('onPlaybackChanged') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @State private containerWidth: number = 360;
  @State private containerHeight: number = 640;
  @State private lyricVm: LyricViewModel = LyricViewModel.getInstance();
  @State private updateIntervalId: number | null = null;
  @State private lastPositionMs: number = 0;
  @State private showLyricAdjust: boolean = false;
  @State private isFullscreenLyric: boolean = false;

  aboutToAppear(): void {
    this.loadLyricsIfNeeded();
    this.startLyricUpdateTimer();
  }

  aboutToDisappear(): void {
    this.stopLyricUpdateTimer();
  }

  private startLyricUpdateTimer(): void {
    this.stopLyricUpdateTimer();
    this.updateIntervalId = setInterval(() => {
      this.updateLyricPosition();
    }, 100) as number;
  }

  private stopLyricUpdateTimer(): void {
    if (this.updateIntervalId !== null) {
      clearInterval(this.updateIntervalId);
      this.updateIntervalId = null;
    }
  }

  private onPlaybackChanged(): void {
    this.loadLyricsIfNeeded();
    this.updateLyricPosition();
  }

  private updateLyricPosition(): void {
    if (this.lyricVm.lines.length === 0) {
      return;
    }
    const currentPositionMs = PlaybackService.getAuthoritativePositionMs();
    if (currentPositionMs === this.lastPositionMs) {
      return;
    }
    this.lastPositionMs = currentPositionMs;
    this.lyricVm.updatePosition(currentPositionMs);
  }

  private loadLyricsIfNeeded(): void {
    if (this.playback.track !== null) {
      void this.lyricVm.loadLyrics(
        this.playback.track.id,
        this.playback.track.artist,
        this.playback.track.title
      );
    }
  }

  private onPlayPauseTap(): void {
    if (!AuthStore.getInstance().isLoggedIn()) {
      ToastUtil.show(this, '请先登录');
      return;
    }
    void PlaybackService.toggle();
  }

  private onPreviousTap(): void {
    if (!AuthStore.getInstance().isLoggedIn()) {
      ToastUtil.show(this, '请先登录');
      return;
    }
    void PlaybackService.playPrevious();
  }

  private onNextTap(): void {
    if (!AuthStore.getInstance().isLoggedIn()) {
      ToastUtil.show(this, '请先登录');
      return;
    }
    void PlaybackService.playNext();
  }

  private onModeTap(): void {
    const newMode = PlaybackService.togglePlaybackMode();
    ToastUtil.show(this, this.getModeText(newMode));
  }

  private onQueueTap(): void {
    PlaylistSheetOpener.requestOpen();
  }

  private onLyricLineClick(lineIndex: number, timeMs: number): void {
    if (!AuthStore.getInstance().isLoggedIn()) {
      ToastUtil.show(this, '请先登录');
      return;
    }
    void PlaybackService.seekTo(timeMs);
    ToastUtil.show(this, `跳转到 ${this.formatTime(timeMs)}`);
  }

  private onOffsetIncrease(): void {
    this.lyricVm.increaseOffset();
    ToastUtil.show(this, `歌词偏移: ${this.lyricVm.getOffsetText()}`);
  }

  private onOffsetDecrease(): void {
    this.lyricVm.decreaseOffset();
    ToastUtil.show(this, `歌词偏移: ${this.lyricVm.getOffsetText()}`);
  }

  private onOffsetReset(): void {
    this.lyricVm.resetOffset();
    ToastUtil.show(this, '歌词偏移已重置');
  }

  private toggleFullscreenLyric(): void {
    this.isFullscreenLyric = !this.isFullscreenLyric;
  }

  private formatTime(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }

  private getModeIcon(mode: PlaybackMode): Resource {
    switch (mode) {
      case 'listLoop':
        return $r('app.media.cb_mode_list');
      case 'singleLoop':
        return $r('app.media.cb_mode_loop');
      case 'random':
        return $r('app.media.cb_mode_shuffle');
      default:
        return $r('app.media.cb_mode_list');
    }
  }

  private getModeText(mode: PlaybackMode): string {
    switch (mode) {
      case 'listLoop':
        return '列表循环';
      case 'singleLoop':
        return '单曲循环';
      case 'random':
        return '随机播放';
      default:
        return '列表循环';
    }
  }

  private coverSize(): number {
    return Math.min(this.containerWidth * 0.65, 320);
  }

  private miniLyricHeight(): number {
    return 130;
  }

  private fullscreenLyricHeight(): number {
    return this.containerHeight - this.topInset - this.bottomInset - 140;
  }

  private trackTitle(): string {
    return this.playback.track?.title ?? '未播放';
  }

  private trackArtist(): string {
    return this.playback.track?.artist ?? '';
  }

  private isLoading(): boolean {
    return this.lyricVm.loadState === 'loading';
  }

  @Builder
  private buildTrackInfo(clickable: boolean) {
    Column({ space: 6 }) {
      Text(this.trackTitle())
        .fontSize(clickable ? 26 : 22)
        .fontWeight(FontWeight.Medium)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('85%')
        .textAlign(TextAlign.Center)

      Text(this.trackArtist())
        .fontSize(clickable ? 18 : 16)
        .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('75%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ 
      top: clickable ? 20 : 14, 
      bottom: clickable ? 20 : 14 
    })
    .onClick(() => {
      if (clickable) {
        this.toggleFullscreenLyric();
      }
    })
  }

  @Builder
  private buildLyricAdjustPanel() {
    Row({ space: 10 }) {
      Button() {
        Column() {
          Text('-')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
      }
      .width(44)
      .height(36)
      .backgroundColor(UiTokens.COLOR_CARD_BG)
      .borderRadius(10)
      .onClick(() => {
        this.onOffsetDecrease();
      })

      Column({ space: 1 }) {
        Text(this.lyricVm.getOffsetText())
          .fontSize(16)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
        Text('歌词偏移')
          .fontSize(11)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .width(70)
      .justifyContent(FlexAlign.Center)

      Button() {
        Column() {
          Text('+')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
      }
      .width(44)
      .height(36)
      .backgroundColor(UiTokens.COLOR_CARD_BG)
      .borderRadius(10)
      .onClick(() => {
        this.onOffsetIncrease();
      })

      Button() {
        Text('重置')
          .fontSize(14)
          .fontColor(UiTokens.COLOR_PRIMARY)
      }
      .width(52)
      .height(36)
      .backgroundColor(UiTokens.COLOR_CARD_BG)
      .borderRadius(10)
      .onClick(() => {
        this.onOffsetReset();
      })
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private buildPlayControls() {
    Column({ space: 10 }) {
      // 主控制按钮行
      Row({ space: 36 }) {
        // 上一曲
        Button() {
          Image($r('app.media.cb_prev'))
            .width(26)
            .height(26)
            .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
        }
        .width(52)
        .height(52)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onPreviousTap();
        })

        // 播放/暂停
        Button() {
          if (this.playback.isPlaying()) {
            Image($r('app.media.cb_pause'))
              .width(32)
              .height(32)
              .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
          } else {
            Image($r('app.media.cb_play'))
              .width(32)
              .height(32)
              .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
          }
        }
        .width(64)
        .height(64)
        .backgroundColor(UiTokens.COLOR_PRIMARY)
        .borderRadius(32)
        .shadow({
          radius: 12,
          color: '#40000000',
          offsetX: 0,
          offsetY: 4
        })
        .onClick(() => {
          this.onPlayPauseTap();
        })

        // 下一曲
        Button() {
          Image($r('app.media.cb_next'))
            .width(26)
            .height(26)
            .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
        }
        .width(52)
        .height(52)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onNextTap();
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      // 功能按钮行
      Row({ space: 18 }) {
        Button() {
          Image(this.getModeIcon(this.playback.mode))
            .width(20)
            .height(20)
            .fillColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
        .width(44)
        .height(44)
        .backgroundColor(UiTokens.COLOR_CARD_BG)
        .borderRadius(12)
        .onClick(() => {
          this.onModeTap();
        })

        Button() {
          Text('±')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.showLyricAdjust ? UiTokens.COLOR_PRIMARY : UiTokens.COLOR_TEXT_SECONDARY)
        }
        .width(44)
        .height(44)
        .backgroundColor(UiTokens.COLOR_CARD_BG)
        .borderRadius(12)
        .onClick(() => {
          this.showLyricAdjust = !this.showLyricAdjust;
        })

        Button() {
          Image($r('app.media.cb_queue'))
            .width(20)
            .height(20)
            .fillColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
        .width(44)
        .height(44)
        .backgroundColor(UiTokens.COLOR_CARD_BG)
        .borderRadius(12)
        .onClick(() => {
          this.onQueueTap();
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      // 歌词偏移调整面板
      if (this.showLyricAdjust && this.lyricVm.hasLyrics()) {
        this.buildLyricAdjustPanel()
      }
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  /**
   * 封面模式布局
   */
  @Builder
  private buildCoverMode() {
    Column() {
      Column()
        .width('100%')
        .height(this.topInset)

      // 专辑封面（放大，带阴影）
      Column() {
        OuterScreenCoverStack({
          discSize: this.coverSize()
        })
      }
      .width(this.coverSize() + 20)
      .height(this.coverSize() + 20)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 16 })

      // 歌曲信息
      this.buildTrackInfo(true)

      // 歌词区域（三行）
      Column() {
        LyricView({
          lines: this.lyricVm.lines,
          currentLineIndex: this.lyricVm.currentLineIndex,
          visible: this.lyricVm.hasLyrics(),
          viewHeight: this.miniLyricHeight(),
          lineHeight: 36,
          activeFontSize: 18,
          inactiveFontSize: 15,
          activeColor: UiTokens.COLOR_PRIMARY,
          inactiveColor: UiTokens.COLOR_TEXT_SECONDARY,
          isLoading: this.isLoading(),
          hasLyrics: this.lyricVm.hasLyrics(),
          isFullscreen: false,
          onLineClick: () => {
            this.toggleFullscreenLyric();
          }
        })
      }
      .width('100%')
      .height(this.miniLyricHeight())
      .onClick(() => {
        this.toggleFullscreenLyric();
      })

      Blank()
        .height(6)

      // 播放进度条
      Column() {
        OuterScreenProgressBar({
          barWidth: this.containerWidth * 0.88
        })
      }
      .width(this.containerWidth * 0.88)
      .padding({ left: 8, right: 8 })

      // 播放控制按钮
      this.buildPlayControls()

      Column()
        .width('100%')
        .height(this.bottomInset)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 全屏歌词模式布局
   */
  @Builder
  private buildFullscreenLyricMode() {
    Column() {
      Column()
        .width('100%')
        .height(this.topInset)

      // 歌曲信息（固定在顶部）
      Column() {
        this.buildTrackInfo(true)
      }
      .width('100%')
      .backgroundColor(UiTokens.COLOR_PAGE_BG)

      // 全屏歌词区域
      LyricView({
        lines: this.lyricVm.lines,
        currentLineIndex: this.lyricVm.currentLineIndex,
        visible: this.lyricVm.hasLyrics(),
        viewHeight: this.fullscreenLyricHeight(),
        lineHeight: 48,
        activeFontSize: 24,
        inactiveFontSize: 18,
        activeColor: UiTokens.COLOR_PRIMARY,
        inactiveColor: UiTokens.COLOR_TEXT_SECONDARY,
        isLoading: this.isLoading(),
        hasLyrics: this.lyricVm.hasLyrics(),
        isFullscreen: true,
        onLineClick: (lineIndex: number, timeMs: number) => {
          this.onLyricLineClick(lineIndex, timeMs);
        }
      })
        .width('100%')

      Blank()
        .height(10)

      // 播放进度条
      Column() {
        OuterScreenProgressBar({
          barWidth: this.containerWidth * 0.88
        })
      }
      .width(this.containerWidth * 0.88)
      .padding({ left: 8, right: 8 })

      // 播放控制按钮
      this.buildPlayControls()

      Column()
        .width('100%')
        .height(this.bottomInset)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      // 封面模式
      Column() {
        this.buildCoverMode()
      }
      .width('100%')
      .height('100%')
      .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
      .visibility(this.isFullscreenLyric ? Visibility.None : Visibility.Visible)

      // 全屏歌词模式
      Column() {
        this.buildFullscreenLyricMode()
      }
      .width('100%')
      .height('100%')
      .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
      .visibility(this.isFullscreenLyric ? Visibility.Visible : Visibility.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(UiTokens.COLOR_PAGE_BG)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      if (newValue.width !== undefined) {
        this.containerWidth = Math.floor(Number(newValue.width));
      }
      if (newValue.height !== undefined) {
        this.containerHeight = Math.floor(Number(newValue.height));
      }
    })
  }
}
