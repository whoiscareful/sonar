import { OuterScreenCoverStack } from '../components/playback/OuterScreenCoverStack';
import { OuterScreenProgressBar } from '../components/playback/OuterScreenProgressBar';
import { LyricViewModel } from '../viewmodel/LyricViewModel';
import { PlaybackSnapshot } from '../playback/PlaybackSnapshot';
import { PlaybackService } from '../playback/PlaybackService';
import { UiTokens } from '../ui/tokens/UiTokens';
import { LyricsLine } from '../api/SubsonicTypes';

/**
 * 外屏歌词显示组件（精简版，只显示当前行和下一行）
 */
@Component
struct OuterScreenLyricView {
  @Prop lines: LyricsLine[] = [];
  @Prop currentLineIndex: number = -1;
  @Prop visible: boolean = true;
  @Prop activeColor: ResourceColor = UiTokens.COLOR_PRIMARY;
  @Prop inactiveColor: ResourceColor = UiTokens.COLOR_TEXT_SECONDARY;
  @Prop isLoading: boolean = false;
  @Prop hasLyrics: boolean = false;

  build() {
    Column({ space: 3 }) {
      if (!this.visible || this.lines.length === 0) {
        // 无歌词或加载中
        if (this.isLoading) {
          Text('加载中…')
            .fontSize(13)
            .fontColor(this.inactiveColor)
        } else {
          Text('暂无歌词')
            .fontSize(13)
            .fontColor(this.inactiveColor)
        }
      } else {
        // 当前行
        if (this.currentLineIndex >= 0 && this.currentLineIndex < this.lines.length) {
          Text(this.lines[this.currentLineIndex].text)
            .fontSize(15)
            .fontColor(this.activeColor)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('90%')
            .textAlign(TextAlign.Center)
        } else {
          Text('♪')
            .fontSize(15)
            .fontColor(this.inactiveColor)
        }

        // 下一行（预览）
        if (this.currentLineIndex + 1 < this.lines.length) {
          Text(this.lines[this.currentLineIndex + 1].text)
            .fontSize(13)
            .fontColor(this.inactiveColor)
            .opacity(0.6)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('85%')
            .textAlign(TextAlign.Center)
        }
      }
    }
    .width('100%')
    .height(46)
    .justifyContent(FlexAlign.Center)
  }
}

@Component
export struct OuterScreenPlayerPage {
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @StorageLink('playback') @Watch('onPlaybackChanged') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @State private containerWidth: number = 360;
  @State private containerHeight: number = 360;
  @State private lyricVm: LyricViewModel = LyricViewModel.getInstance();
  @State private updateIntervalId: number | null = null;
  @State private lastPositionMs: number = 0;

  /**
   * 外屏封面大小（减小以留出更多空间给歌词）
   */
  private coverDiscSize(): number {
    const minEdge: number = Math.min(this.containerWidth, this.containerHeight);
    if (minEdge <= 0) {
      return 180;
    }
    // 减小封面比例，从原来的比例降低到 0.35
    return Math.floor(minEdge * 0.35);
  }

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

  private loadLyricsIfNeeded(): void {
    if (this.playback.track === null) {
      return;
    }
    void this.lyricVm.loadLyrics(
      this.playback.track.id,
      this.playback.track.artist,
      this.playback.track.title
    );
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

  build() {
    Column() {
      Blank()
        .layoutWeight(1)

      // 专辑封面（减小尺寸）
      OuterScreenCoverStack({ discSize: this.coverDiscSize() })

      Blank()
        .height(6)

      // 进度条
      OuterScreenProgressBar({ barWidth: this.coverDiscSize() })

      Blank()
        .height(6)

      // 精简歌词显示（只显示两行）
      OuterScreenLyricView({
        lines: this.lyricVm.lines,
        currentLineIndex: this.lyricVm.currentLineIndex,
        visible: this.lyricVm.hasLyrics(),
        activeColor: UiTokens.COLOR_PRIMARY,
        inactiveColor: UiTokens.COLOR_TEXT_SECONDARY,
        isLoading: this.lyricVm.loadState === 'loading',
        hasLyrics: this.lyricVm.hasLyrics()
      })

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.topInset,
      bottom: this.bottomInset
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((_oldValue, newValue) => {
      let widthVp: number = 0;
      let heightVp: number = 0;
      if (typeof newValue.width === 'number') {
        widthVp = newValue.width;
      }
      if (typeof newValue.height === 'number') {
        heightVp = newValue.height;
      }
      if (widthVp > 0 && widthVp !== this.containerWidth) {
        this.containerWidth = widthVp;
      }
      if (heightVp > 0 && heightVp !== this.containerHeight) {
        this.containerHeight = heightVp;
      }
    })
  }
}
