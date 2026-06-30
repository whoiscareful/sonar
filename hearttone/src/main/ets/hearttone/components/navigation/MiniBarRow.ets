import { PlaybackService } from '../../playback/PlaybackService';
import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { PlaylistSheetController } from '../playlist/PlaylistSheetController';
import { BarToneColorAnimator } from '../../ui/color/BarToneColorAnimator';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { AutoMarqueeText } from '../layout/AutoMarqueeText';
import { MINI_BAR_COMPACT_KEY } from './MiniBarStateKeys';
import { MiniBarCoverDisc } from './MiniBarCoverDisc';

const BAR_TONE_COLOR_ANIM_MS: number = 280;
const TONE_COLOR_ANIM_CURVE: Curve = Curve.EaseInOut;

/**
 * 官方 miniBar 模型：单一 Row + width('100%') + clip(true)。
 * 目标色经 AppStorage 注入；BarToneColorAnimator 280ms 插值 + .animation 平滑。
 * 收起态不拦截点击/手势，交由 HDS 展开 miniBar；展开态才启用播放/暂停与上滑打开列表。
 */
@Component
export struct MiniBarRow {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop @Watch('onToneTargetChange') targetInactive: string = '#282A32';
  @Prop @Watch('onToneTargetChange') targetPrimary: string = '#1B1D23';
  @Prop @Watch('onToneTargetChange') targetSecondary: string = '#3C3F4A';
  @StorageLink('playback') @Watch('onPlaybackSync') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @StorageProp(MINI_BAR_COMPACT_KEY) miniBarCompact: boolean = true;

  @State private displayInactive: string = '#282A32';
  @State private displayPrimary: string = '#1B1D23';
  @State private displaySecondary: string = '#3C3F4A';
  @State private toneAnimReady: boolean = false;
  @State private coverControlOpacity: number = 0;

  private colorAnimator: BarToneColorAnimator = new BarToneColorAnimator();
  private hideOverlayTimerId: number = -1;
  private lastSyncedTrackId: string = '';
  private lastSyncedPlaying: boolean = false;
  private readonly playlistSheetController: PlaylistSheetController = PlaylistSheetController.getInstance();

  aboutToAppear(): void {
    this.lastSyncedTrackId = this.playback.track !== null ? this.playback.track.id : '';
    this.lastSyncedPlaying = this.playback.isPlaying();
    this.applyDisplayColors(false);
    if (this.hasActiveTrack() && !this.lastSyncedPlaying && this.canTogglePlayback()) {
      this.revealCoverControl(false);
    }
  }

  aboutToDisappear(): void {
    this.colorAnimator.stop();
    this.clearHideOverlayTimer();
  }

  private onPlaybackSync(): void {
    const trackId: string = this.playback.track !== null ? this.playback.track.id : '';
    if (trackId !== this.lastSyncedTrackId) {
      this.lastSyncedTrackId = trackId;
      this.lastSyncedPlaying = this.playback.isPlaying();
      this.clearHideOverlayTimer();
      this.coverControlOpacity = 0;
      return;
    }
    if (this.playback.isCoverLoading()) {
      this.lastSyncedPlaying = this.playback.isPlaying();
      this.clearHideOverlayTimer();
      this.coverControlOpacity = 0;
      return;
    }
    const isPlaying: boolean = this.playback.isPlaying();
    if (this.lastSyncedPlaying && !isPlaying && this.canTogglePlayback()) {
      this.revealCoverControl(false);
    }
    this.lastSyncedPlaying = isPlaying;
  }

  private clearHideOverlayTimer(): void {
    if (this.hideOverlayTimerId >= 0) {
      clearTimeout(this.hideOverlayTimerId);
      this.hideOverlayTimerId = -1;
    }
  }

  private scheduleCoverControlHide(): void {
    this.clearHideOverlayTimer();
    this.hideOverlayTimerId = setTimeout(() => {
      this.hideOverlayTimerId = -1;
      this.getUIContext()?.animateTo(
        {
          duration: UiTokens.MINI_BAR_COVER_CONTROL_FADE_MS,
          curve: Curve.EaseOut
        },
        () => {
          this.coverControlOpacity = 0;
        }
      );
    }, UiTokens.MINI_BAR_COVER_CONTROL_HIDE_DELAY_MS);
  }

  /** 点击封面：立即展示控件；暂停→播放时 2s 后渐隐，播放→暂停时保持当前透明度。 */
  private revealCoverControl(autoHideAfterDelay: boolean): void {
    this.clearHideOverlayTimer();
    this.coverControlOpacity = 1;
    if (autoHideAfterDelay) {
      this.scheduleCoverControlHide();
    }
  }

  private onToneTargetChange(): void {
    this.applyDisplayColors(this.toneAnimReady);
  }

  private applyDisplayColors(animated: boolean): void {
    if (!animated) {
      this.colorAnimator.stop();
      this.displayInactive = this.targetInactive;
      this.displayPrimary = this.targetPrimary;
      this.displaySecondary = this.targetSecondary;
      this.toneAnimReady = true;
      return;
    }

    this.colorAnimator.animateTriple(
      this.displayInactive,
      this.targetInactive,
      this.displayPrimary,
      this.targetPrimary,
      this.displaySecondary,
      this.targetSecondary,
      BAR_TONE_COLOR_ANIM_MS,
      (inactive: string, primary: string, secondary: string) => {
        this.displayInactive = inactive;
        this.displayPrimary = primary;
        this.displaySecondary = secondary;
      }
    );
  }

  private hasActiveTrack(): boolean {
    return this.playback.showMiniPlayer;
  }

  private isMiniBarExpanded(): boolean {
    return !this.miniBarCompact;
  }

  private canTogglePlayback(): boolean {
    return this.isMiniBarExpanded() && this.hasActiveTrack();
  }

  private shouldShowCoverPlayPauseOverlay(): boolean {
    return this.canTogglePlayback() && !this.playback.isCoverLoading();
  }

  private coverOuterSize(): number {
    return UiTokens.FLOATING_TAB_BAR_HEIGHT;
  }

  private coverInset(): number {
    return UiTokens.MINI_BAR_BALL_COVER_INSET;
  }

  private coverInnerSize(): number {
    return Math.max(0, this.coverOuterSize() - this.coverInset() * 2);
  }

  private onCoverTap(): void {
    if (!this.canTogglePlayback()) {
      return;
    }
    const wasPlaying: boolean = this.playback.isPlaying();
    if (wasPlaying) {
      this.revealCoverControl(false);
    } else {
      this.clearHideOverlayTimer();
      this.coverControlOpacity = 0;
    }
    void PlaybackService.toggle();
  }

  private onPlaylistSheetPanStart(): void {
    this.playlistSheetController.beginDrag();
  }

  private onPlaylistSheetPanUpdate(event: GestureEvent): void {
    this.playlistSheetController.updateDragHeight(event.offsetY);
  }

  private onPlaylistSheetPanEnd(event: GestureEvent): void {
    this.playlistSheetController.endDrag(event.offsetY, event.velocityY);
  }

  private titleText(): string {
    if (!this.hasActiveTrack()) {
      return '当前未播放音乐';
    }
    if (this.playback.track !== null && this.playback.track.title.length > 0) {
      return this.playback.track.title;
    }
    return '未知曲目';
  }

  private artistText(): string {
    if (this.playback.track !== null && this.playback.track.artist.length > 0) {
      return this.playback.track.artist;
    }
    return '未知歌手';
  }

  @Builder
  private coverPlayPauseOverlay() {
    if (this.shouldShowCoverPlayPauseOverlay()) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(this.coverInnerSize())
          .height(this.coverInnerSize())
          .borderRadius(this.coverInnerSize() / 2)
          .backgroundColor(UiTokens.COLOR_OVERLAY_SCRIM)
        if (this.playback.isPlaying()) {
          Image($r('app.media.cb_pause'))
            .width(UiTokens.MINI_BAR_COVER_PLAY_ICON_SIZE)
            .height(UiTokens.MINI_BAR_COVER_PLAY_ICON_SIZE)
            .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
        } else {
          Image($r('app.media.cb_play'))
            .width(UiTokens.MINI_BAR_COVER_PLAY_ICON_SIZE)
            .height(UiTokens.MINI_BAR_COVER_PLAY_ICON_SIZE)
            .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
        }
      }
      .opacity(this.coverControlOpacity)
      .animation({
        duration: UiTokens.MINI_BAR_COVER_CONTROL_FADE_MS,
        curve: Curve.EaseOut
      })
      .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  private coverDisc() {
    MiniBarCoverDisc({
      outerSize: this.coverOuterSize(),
      coverInset: this.coverInset(),
      idleIconColor: this.displayInactive
    })
  }

  @Builder
  private coverSectionCollapsed() {
    Stack({ alignContent: Alignment.Center }) {
      this.coverDisc()
    }
    .width(this.coverOuterSize())
    .height(this.coverOuterSize())
    .flexShrink(0)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private coverSectionExpanded() {
    Stack({ alignContent: Alignment.Center }) {
      this.coverDisc()
      this.coverPlayPauseOverlay()
    }
    .width(this.coverOuterSize())
    .height(this.coverOuterSize())
    .flexShrink(0)
    .accessibilityText(this.shouldShowCoverPlayPauseOverlay() ?
      (this.playback.isPlaying() ? '暂停' : '播放') : '')
    .onClick(() => {
      this.onCoverTap();
    })
  }

  @Builder
  private coverSection() {
    if (this.isMiniBarExpanded()) {
      this.coverSectionExpanded()
    } else {
      this.coverSectionCollapsed()
    }
  }

  @Builder
  private actionIcon(icon: Resource, iconSize: number, a11yLabel: string, onTap: () => void) {
    Column() {
      Image(icon)
        .width(iconSize)
        .height(iconSize)
        .fillColor(this.displayPrimary)
        .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
    }
    .width(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .height(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .accessibilityText(a11yLabel)
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  private miniBarContent() {
    this.coverSection()

    Column({ space: UiTokens.MINI_BAR_TEXT_LINE_GAP }) {
      AutoMarqueeText({
        text: this.titleText(),
        fontSize: UiTokens.MINI_BAR_TITLE_FONT_SIZE,
        fontWeight: FontWeight.Medium,
        fontColor: this.hasActiveTrack() ? this.displayPrimary : this.displayInactive
      })
        .width('100%')
        .height(UiTokens.MINI_BAR_TITLE_LINE_HEIGHT)
        .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
      if (this.hasActiveTrack()) {
        Text(this.artistText())
          .fontSize(UiTokens.MINI_BAR_ARTIST_FONT_SIZE)
          .fontColor(this.displaySecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
      }
    }
    .layoutWeight(1)
    .flexShrink(1)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .hitTestBehavior(this.miniBarCompact ? HitTestMode.None : HitTestMode.Default)
    .onClick(() => {
      // 点击中间部分（歌名与作者）进入播放详情页
      if (!this.miniBarCompact && this.hasActiveTrack()) {
        this.appPathStack.pushPathByName('NowPlayingPage', null);
      }
    })
    .priorityGesture(
      PanGesture({ direction: PanDirection.Vertical, distance: 1 })
        .onActionStart(() => {
          if (!this.isMiniBarExpanded()) {
            return;
          }
          this.onPlaylistSheetPanStart();
        })
        .onActionUpdate((event: GestureEvent) => {
          if (!this.isMiniBarExpanded()) {
            return;
          }
          this.onPlaylistSheetPanUpdate(event);
        })
        .onActionEnd((event: GestureEvent) => {
          if (!this.isMiniBarExpanded()) {
            return;
          }
          this.onPlaylistSheetPanEnd(event);
        })
    )

    if (this.isMiniBarExpanded() && this.hasActiveTrack()) {
      Row({ space: UiTokens.MINI_PLAYER_ACTION_ICON_GAP }) {
        this.actionIcon($r('app.media.cb_next'), 22, '下一首', () => {
          void PlaybackService.playNext(true);
        })
      }
      .flexShrink(0)
      .padding({ right: UiTokens.MINI_BAR_HORIZONTAL_INSET })
    }
  }

  build() {
    Row({ space: UiTokens.MINI_PLAYER_CAPSULE_CONTENT_GAP }) {
      this.miniBarContent()
    }
    .width('100%')
    .height(UiTokens.FLOATING_TAB_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .clip(true)
    .hitTestBehavior(this.miniBarCompact ? HitTestMode.None : HitTestMode.Default)
  }
}
