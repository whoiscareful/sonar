import { PlaybackService } from '../../playback/PlaybackService';
import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { OuterScreenPalette, OuterScreenTheme } from '../../ui/adaptation/OuterScreenTheme';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct OuterScreenProgressBar {
  @Prop barWidth: number = 200;
  @StorageLink('playback') @Watch('onPlaybackChanged') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @StorageLink('currentColorMode') currentColorMode: number = 0;
  @State private dragRatio: number = 0;
  @State private isDragging: boolean = false;

  private palette(): OuterScreenPalette {
    return OuterScreenTheme.palette(OuterScreenTheme.isDarkUi(this.currentColorMode));
  }

  private hasSeekableTrack(): boolean {
    return this.playback.showMiniPlayer &&
      this.playback.track !== null &&
      this.playback.track.durationMs > 0;
  }

  private progressRatio(): number {
    if (!this.hasSeekableTrack() || this.playback.track === null) {
      return 0;
    }
    const durationMs: number = this.playback.track.durationMs;
    if (durationMs <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(1, this.playback.positionMs / durationMs));
  }

  private trackWidthVp(): number {
    return this.barWidth * UiTokens.OUTER_SCREEN_PROGRESS_WIDTH_RATIO;
  }

  private activeRatio(): number {
    if (this.isDragging) {
      return this.dragRatio;
    }
    return this.progressRatio();
  }

  private fillWidthVp(trackWidth: number, ratio: number): number {
    return ratio * trackWidth;
  }

  private thumbLeftVp(trackWidth: number, ratio: number): number {
    const thumbSize: number = UiTokens.OUTER_SCREEN_PROGRESS_THUMB_SIZE;
    return Math.max(0, Math.min(trackWidth - thumbSize, ratio * trackWidth - thumbSize / 2));
  }

  private syncDragFromPlayback(): void {
    if (this.isDragging) {
      return;
    }
    this.dragRatio = this.progressRatio();
  }

  aboutToAppear(): void {
    this.syncDragFromPlayback();
  }

  private onPlaybackChanged(): void {
    this.syncDragFromPlayback();
  }

  private clampRatio(raw: number): number {
    return Math.max(0, Math.min(1, raw));
  }

  private commitSeek(ratio: number): void {
    if (!this.hasSeekableTrack() || this.playback.track === null) {
      return;
    }
    const targetMs: number = Math.floor(this.playback.track.durationMs * ratio);
    void PlaybackService.seekTo(targetMs);
  }

  private handleTouch(event: TouchEvent, trackWidth: number): void {
    if (!this.hasSeekableTrack() || trackWidth <= 0 || event.touches.length === 0) {
      return;
    }
    const localX: number = event.touches[0].x;
    const ratio: number = this.clampRatio(localX / trackWidth);
    if (event.type === TouchType.Down) {
      this.isDragging = true;
      this.dragRatio = ratio;
      return;
    }
    if (event.type === TouchType.Move && this.isDragging) {
      this.dragRatio = ratio;
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.isDragging) {
        this.dragRatio = ratio;
        this.commitSeek(ratio);
      }
      this.isDragging = false;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width(this.trackWidthVp())
          .height(UiTokens.OUTER_SCREEN_PROGRESS_HEIGHT)
          .backgroundColor(this.palette().progressTrack)
          .borderRadius(UiTokens.OUTER_SCREEN_PROGRESS_HEIGHT)
          .position({
            x: 0,
            y: (UiTokens.OUTER_SCREEN_PROGRESS_TOUCH_HEIGHT - UiTokens.OUTER_SCREEN_PROGRESS_HEIGHT) / 2
          })

        if (this.hasSeekableTrack() && this.fillWidthVp(this.trackWidthVp(), this.activeRatio()) > 0) {
          Row()
            .width(this.fillWidthVp(this.trackWidthVp(), this.activeRatio()))
            .height(UiTokens.OUTER_SCREEN_PROGRESS_HEIGHT)
            .backgroundColor(this.palette().progressFill)
            .borderRadius(UiTokens.OUTER_SCREEN_PROGRESS_HEIGHT)
            .position({
              x: 0,
              y: (UiTokens.OUTER_SCREEN_PROGRESS_TOUCH_HEIGHT - UiTokens.OUTER_SCREEN_PROGRESS_HEIGHT) / 2
            })
            .animation(this.isDragging ? { duration: 0 } : { duration: 180, curve: Curve.Linear })
        }

        if (this.hasSeekableTrack()) {
          Row()
            .width(UiTokens.OUTER_SCREEN_PROGRESS_THUMB_SIZE)
            .height(UiTokens.OUTER_SCREEN_PROGRESS_THUMB_SIZE)
            .borderRadius(UiTokens.OUTER_SCREEN_PROGRESS_THUMB_SIZE / 2)
            .backgroundColor(this.palette().progressThumb)
            .shadow({
              radius: 6,
              color: '#66000000',
              offsetX: 0,
              offsetY: 1
            })
            .position({
              x: this.thumbLeftVp(this.trackWidthVp(), this.activeRatio()),
              y: (UiTokens.OUTER_SCREEN_PROGRESS_TOUCH_HEIGHT - UiTokens.OUTER_SCREEN_PROGRESS_THUMB_SIZE) / 2
            })
            .animation(this.isDragging ? { duration: 0 } : { duration: 180, curve: Curve.Linear })
        }
      }
      .width(this.trackWidthVp())
      .height(UiTokens.OUTER_SCREEN_PROGRESS_TOUCH_HEIGHT)
    }
    .width(this.trackWidthVp())
    .height(UiTokens.OUTER_SCREEN_PROGRESS_TOUCH_HEIGHT)
    .opacity(this.hasSeekableTrack() ? 1 : 0.45)
    .onTouch((event: TouchEvent) => {
      this.handleTouch(event, this.trackWidthVp());
    })
  }
}
