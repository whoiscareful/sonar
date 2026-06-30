import { AuthStore } from '../../auth/AuthStore';
import { ToastUtil } from '../../common/ToastUtil';
import { PlaybackService } from '../../playback/PlaybackService';
import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { OuterScreenPalette, OuterScreenTheme } from '../../ui/adaptation/OuterScreenTheme';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { PlaybackCoverDisc } from './PlaybackCoverDisc';

@Component
export struct OuterScreenCoverStack {
  @Prop discSize: number = 220;
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @StorageLink('currentColorMode') currentColorMode: number = 0;

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
    if (!AuthStore.getInstance().isLoggedIn()) {
      ToastUtil.show(this, '请先登录');
      return;
    }
    void PlaybackService.toggle();
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
  }
}
