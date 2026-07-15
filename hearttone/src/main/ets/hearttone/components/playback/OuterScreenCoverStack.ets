import { AuthStore } from '../../auth/AuthStore';
import { ToastUtil } from '../../common/ToastUtil';
import { PlaybackService } from '../../playback/PlaybackService';
import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { OuterScreenPalette, OuterScreenTheme } from '../../ui/adaptation/OuterScreenTheme';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { PlaybackCoverDisc } from './PlaybackCoverDisc';

const COVER_DRAG_MAX_OFFSET: number = 42;
const COVER_DRAG_DAMPING: number = 0.32;

@Component
export struct OuterScreenCoverStack {
  @Prop discSize: number = 220;
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @StorageLink('currentColorMode') currentColorMode: number = 0;
  @State private dragOffsetX: number = 0;
  @State private dragOffsetY: number = 0;
  @State private isDragging: boolean = false;
  @State private dragMoved: boolean = false;

  private palette(): OuterScreenPalette {
    return OuterScreenTheme.palette(OuterScreenTheme.isDarkUi(this.currentColorMode));
  }

  private coverArtId(): string {
    if (this.playback.track === null) {
      return '';
    }
    return this.playback.track.coverArtId;
  }

  private trackId(): string {
    if (this.playback.track === null) {
      return '';
    }
    return this.playback.track.id;
  }

  private onPlayPauseTap(): void {
    if (this.dragMoved) {
      this.dragMoved = false;
      return;
    }
    if (!AuthStore.getInstance().isLoggedIn()) {
      ToastUtil.show(this, '请先登录');
      return;
    }
    void PlaybackService.toggle();
  }

  private rubberBandOffset(rawOffset: number): number {
    const damped: number = rawOffset * COVER_DRAG_DAMPING;
    if (damped > COVER_DRAG_MAX_OFFSET) {
      return COVER_DRAG_MAX_OFFSET;
    }
    if (damped < -COVER_DRAG_MAX_OFFSET) {
      return -COVER_DRAG_MAX_OFFSET;
    }
    return damped;
  }

  private dragTiltAngle(): number {
    if (COVER_DRAG_MAX_OFFSET <= 0) {
      return 0;
    }
    return (this.dragOffsetX / COVER_DRAG_MAX_OFFSET) * 5;
  }

  private dragScale(): number {
    const distance: number = Math.sqrt(this.dragOffsetX * this.dragOffsetX + this.dragOffsetY * this.dragOffsetY);
    return 1 - Math.min(distance / 840, 0.035);
  }

  private onCoverDragUpdate(event: GestureEvent): void {
    this.isDragging = true;
    this.dragMoved = true;
    this.dragOffsetX = this.rubberBandOffset(event.offsetX);
    this.dragOffsetY = this.rubberBandOffset(event.offsetY);
  }

  private resetCoverDrag(): void {
    this.isDragging = false;
    if (this.dragMoved) {
      setTimeout(() => {
        this.dragMoved = false;
      }, 360);
    }
    this.getUIContext()?.animateTo(
      { duration: 260, curve: Curve.EaseOut },
      () => {
        this.dragOffsetX = 0;
        this.dragOffsetY = 0;
      }
    );
  }

  @Builder
  private playPauseOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(UiTokens.OUTER_SCREEN_PLAY_MASK_SIZE)
        .height(UiTokens.OUTER_SCREEN_PLAY_MASK_SIZE)
        .borderRadius(UiTokens.OUTER_SCREEN_PLAY_MASK_SIZE / 2)
        .backgroundColor(UiTokens.OUTER_SCREEN_PLAY_MASK_COLOR)
      if (this.playback.isPlaying()) {
        Image($r('app.media.cb_pause'))
          .width(UiTokens.OUTER_SCREEN_PLAY_ICON_SIZE)
          .height(UiTokens.OUTER_SCREEN_PLAY_ICON_SIZE)
          .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
      } else {
        Image($r('app.media.cb_play'))
          .width(UiTokens.OUTER_SCREEN_PLAY_ICON_SIZE)
          .height(UiTokens.OUTER_SCREEN_PLAY_ICON_SIZE)
          .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
      }
    }
    .width(UiTokens.OUTER_SCREEN_PLAY_MASK_SIZE)
    .height(UiTokens.OUTER_SCREEN_PLAY_MASK_SIZE)
    .zIndex(2)
    .onClick(() => {
      this.onPlayPauseTap();
    })
    .accessibilityText(this.playback.isPlaying() ? '暂停' : '播放')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      PlaybackCoverDisc({
        discSize: this.discSize,
        coverArtId: this.coverArtId(),
        coverRevision: this.playback.coverRevision,
        trackId: this.trackId(),
        loading: this.playback.showMiniPlayer && this.playback.isCoverLoading(),
        spinning: this.playback.isPlaying(),
        showCover: this.playback.showMiniPlayer,
        idleIconColor: this.palette().idleCoverIcon
      })

      this.playPauseOverlay()
    }
    .width(this.discSize)
    .height(this.discSize)
    .translate({ x: this.dragOffsetX, y: this.dragOffsetY })
    .scale({ x: this.dragScale(), y: this.dragScale(), centerX: '50%', centerY: '50%' })
    .rotate({
      x: 0,
      y: 1,
      z: 0,
      angle: this.dragTiltAngle(),
      centerX: '50%',
      centerY: '50%'
    })
    .animation(this.isDragging ? { duration: 0 } : { duration: 260, curve: Curve.EaseOut })
    .parallelGesture(
      PanGesture({ direction: PanDirection.All, distance: 1 })
        .onActionUpdate((event: GestureEvent) => {
          this.onCoverDragUpdate(event);
        })
        .onActionEnd(() => {
          this.resetCoverDrag();
        })
        .onActionCancel(() => {
          this.resetCoverDrag();
        })
    )
  }
}
