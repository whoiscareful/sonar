import { OuterScreenCoverStack } from '../components/playback/OuterScreenCoverStack';
import { OuterScreenProgressBar } from '../components/playback/OuterScreenProgressBar';
import { LyricView } from '../components/lyrics/LyricView';
import { LyricViewModel } from '../viewmodel/LyricViewModel';
import { PlaybackMode, PlaybackSnapshot } from '../playback/PlaybackSnapshot';
import { PlaybackService } from '../playback/PlaybackService';
import { UiTokens } from '../ui/tokens/UiTokens';
import { AuthStore } from '../auth/AuthStore';
import { ToastUtil } from '../common/ToastUtil';
import { PlaylistSheetOpener } from '../components/playlist/PlaylistSheetOpener';
import { FavoriteSyncService } from '../domain/music/FavoriteSyncService';
import { TagButtonMenuItem } from '../components/buttons/TagButton';
import { GlobalPageBackground } from '../components/layout/GlobalPageBackground';
import { SleepTimerService } from '../playback/SleepTimerService';
import promptAction from '@ohos.promptAction';
import { BusinessError } from '@ohos.base';
import { common, Want } from '@kit.AbilityKit';
import { MusicTagWebOpenApiClient } from '../enhanced/MusicTagWebOpenApiClient';

/**
 * 播放详情页。
 * 封面和歌词使用互斥布局，避免透明图层残留导致视觉位置与点击热区错位。
 */
@Component
export struct NowPlayingPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @StorageLink('playback') @Watch('onPlaybackChanged') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @StorageLink('favoriteRevision') @Watch('onFavoriteRevision') favoriteRevision: number = 0;
  @StorageLink('sleepTimerRevision') sleepTimerRevision: number = 0;
  @State private containerWidth: number = 360;
  @State private containerHeight: number = 640;
  @State private lyricVm: LyricViewModel = LyricViewModel.getInstance();
  @State private updateIntervalId: number | null = null;
  @State private lastPositionMs: number = 0;
  @State private showLyricAdjust: boolean = false;
  @StorageLink('nowPlayingLyricsVisible') private showLyrics: boolean = false;
  @State private isFavorite: boolean = false;
  @State private favoriteLoading: boolean = false;
  private favoriteSongId: string = '';
  private readonly favorites: FavoriteSyncService = FavoriteSyncService.getInstance();

  aboutToAppear(): void {
    this.loadLyricsIfNeeded();
    this.loadFavoriteState();
    this.updatePlaybackPosition();
    this.startUpdateTimer();
  }

  aboutToDisappear(): void {
    this.stopUpdateTimer();
    this.showLyrics = false;
  }

  private startUpdateTimer(): void {
    this.stopUpdateTimer();
    this.updateIntervalId = setInterval(() => {
      this.updatePlaybackPosition();
    }, 250) as number;
  }

  private stopUpdateTimer(): void {
    if (this.updateIntervalId !== null) {
      clearInterval(this.updateIntervalId);
      this.updateIntervalId = null;
    }
  }

  private onPlaybackChanged(): void {
    this.loadLyricsIfNeeded();
    this.loadFavoriteState();
    this.updatePlaybackPosition();
  }

  private loadFavoriteState(): void {
    const songId: string = this.playback.track?.id ?? '';
    if (songId.length === 0 || songId === this.favoriteSongId) {
      return;
    }
    this.favoriteSongId = songId;
    this.isFavorite = false;
    void this.favorites.refreshSong(songId).then((favorite: boolean) => {
      if (this.favoriteSongId === songId) {
        this.isFavorite = favorite;
      }
    }).catch(() => {
    });
  }

  private onFavoriteRevision(): void {
    const songId: string = this.playback.track?.id ?? '';
    if (songId.length > 0) {
      this.isFavorite = this.favorites.isFavorite(songId);
    }
  }

  private async toggleFavorite(): Promise<void> {
    const songId: string = this.playback.track?.id ?? '';
    if (!this.ensureLoggedIn() || songId.length === 0 || this.favoriteLoading) {
      return;
    }
    const nextFavorite: boolean = !this.isFavorite;
    this.favoriteLoading = true;
    this.isFavorite = nextFavorite;
    try {
      await this.favorites.setFavorite(songId, nextFavorite);
      ToastUtil.show(this, nextFavorite ? '已添加到喜爱' : '已从喜爱移除');
    } catch (err) {
      if (this.favoriteSongId === songId) {
        this.isFavorite = !nextFavorite;
      }
      ToastUtil.show(this, `喜爱同步失败：${(err as Error).message}`);
    } finally {
      this.favoriteLoading = false;
    }
  }

  private updatePlaybackPosition(): void {
    const currentPositionMs: number = PlaybackService.getAuthoritativePositionMs();
    if (currentPositionMs !== this.lastPositionMs) {
      this.lastPositionMs = currentPositionMs;
    }
    if (this.lyricVm.lines.length > 0) {
      this.lyricVm.updatePosition(currentPositionMs);
    }
  }

  private loadLyricsIfNeeded(): void {
    if (this.playback.track === null) {
      return;
    }
    void this.lyricVm.loadLyrics(
      this.playback.track.id,
      this.playback.track.artist,
      this.playback.track.title,
      this.playback.track.album
    );
  }

  private ensureLoggedIn(): boolean {
    if (AuthStore.getInstance().isLoggedIn()) {
      return true;
    }
    ToastUtil.show(this, '请先登录');
    return false;
  }

  private onBackTap(): void {
    if (this.showLyrics) {
      this.setLyricsVisible(false);
      return;
    }
    if (this.appPathStack.size() > 0) {
      this.appPathStack.pop();
    }
  }

  private onPlayPauseTap(): void {
    if (!this.ensureLoggedIn()) {
      return;
    }
    void PlaybackService.toggle();
  }

  private onPreviousTap(): void {
    if (!this.ensureLoggedIn()) {
      return;
    }
    void PlaybackService.playPrevious();
  }

  private onNextTap(): void {
    if (!this.ensureLoggedIn()) {
      return;
    }
    void PlaybackService.playNext();
  }

  private onQueueTap(): void {
    PlaylistSheetOpener.requestOpen();
  }

  private onLyricLineClick(_lineIndex: number, timeMs: number): void {
    if (!this.ensureLoggedIn()) {
      return;
    }
    this.lastPositionMs = timeMs;
    void PlaybackService.seekTo(timeMs);
    ToastUtil.show(this, `跳转到 ${this.formatTime(timeMs)}`);
  }

  private onOffsetIncrease(): void {
    this.lyricVm.increaseOffset();
    ToastUtil.show(this, `歌词偏移：${this.lyricVm.getOffsetText()}`);
  }

  private onOffsetDecrease(): void {
    this.lyricVm.decreaseOffset();
    ToastUtil.show(this, `歌词偏移：${this.lyricVm.getOffsetText()}`);
  }

  private onOffsetReset(): void {
    this.lyricVm.resetOffset();
    ToastUtil.show(this, '歌词偏移已重置');
  }

  private async saveCurrentLyrics(): Promise<void> {
    try {
      await this.lyricVm.saveCurrentLyrics();
      ToastUtil.show(this, '歌词已保存到 Music Tag Web');
    } catch (err) {
      ToastUtil.show(this, `歌词保存失败：${(err as Error).message}`);
    }
  }

  private async refreshLyricsFromMusicTagWeb(): Promise<void> {
    if (this.playback.track === null) {
      ToastUtil.show(this, '当前没有正在播放的歌曲');
      return;
    }
    const track = this.playback.track;
    this.lyricVm.reset();
    await this.lyricVm.loadLyrics(track.id, track.artist, track.title, track.album);
    if (this.lyricVm.loadState === 'loaded') {
      ToastUtil.show(this, `歌词同步成功 · 来源 ${this.lyricVm.sourceLabel()}`);
    } else if (this.lyricVm.loadState === 'notFound') {
      ToastUtil.show(this, 'Music Tag Web 和 Subsonic 均未找到歌词');
    } else {
      ToastUtil.show(this, `歌词同步失败：${this.lyricVm.errorMessage || '未知错误'}`);
    }
  }

  private openMetadataDetail(): void {
    const path: string = this.playback.track?.path ?? '';
    if (path.length === 0) {
      ToastUtil.show(this, '当前歌曲缺少文件路径，无法打开元数据详情');
      return;
    }
    const url: string = MusicTagWebOpenApiClient.getInstance().metadataDetailUrl(path);
    if (url.length === 0) {
      ToastUtil.show(this, '请先登录服务器');
      return;
    }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = { action: 'ohos.want.action.viewData', uri: url };
    void context.startAbility(want).catch((err: Error) => {
      ToastUtil.show(this, `打开元数据详情失败：${err.message}`);
    });
  }

  private toggleLyrics(): void {
    this.setLyricsVisible(!this.showLyrics);
  }

  private setLyricsVisible(visible: boolean): void {
    this.getUIContext()?.animateTo(
      { duration: 240, curve: Curve.EaseOut },
      () => {
        this.showLyrics = visible;
        if (!visible) {
          this.showLyricAdjust = false;
        }
      }
    );
  }

  private formatTime(ms: number): string {
    const safeMs: number = Math.max(0, ms);
    const totalSeconds: number = Math.floor(safeMs / 1000);
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }

  private getModeText(mode: PlaybackMode): string {
    if (mode === 'singleLoop') {
      return '单曲循环';
    }
    if (mode === 'random') {
      return '随机播放';
    }
    return '列表循环';
  }

  private openSleepTimerMenu(): void {
    this.getUIContext().getPromptAction().showActionMenu({
      title: `定时关闭 · ${SleepTimerService.label()}`,
      buttons: [
        { text: '15 分钟', color: '#1C1C1E' },
        { text: '30 分钟', color: '#1C1C1E' },
        { text: '60 分钟', color: '#1C1C1E' },
        { text: '播完当前歌曲', color: '#1C1C1E' },
        { text: '播完当前专辑', color: '#1C1C1E' },
        { text: '关闭定时', color: '#5B5CE2' }
      ]
    }, (err: BusinessError, response: promptAction.ActionMenuSuccessResponse): void => {
      if (err) {
        return;
      }
      this.handleSleepTimerMenuSelection(response.index);
    });
  }

  private handleSleepTimerMenuSelection(index: number): void {
    const minutes: number[] = [15, 30, 60];
    if (index >= 0 && index < minutes.length) {
      const selectedMinutes: number = minutes[index];
      SleepTimerService.set(selectedMinutes);
      ToastUtil.show(this, `将在 ${selectedMinutes} 分钟后暂停播放`);
    } else if (index === 3) {
      if (SleepTimerService.setUntilCurrentTrackEnds()) {
        ToastUtil.show(this, '将在当前歌曲播完后暂停播放');
      } else {
        ToastUtil.show(this, '当前歌曲时长未知，无法设置');
      }
    } else if (index === 4) {
      if (SleepTimerService.setUntilCurrentAlbumEnds()) {
        ToastUtil.show(this, '将在当前专辑播完后暂停播放');
      } else {
        ToastUtil.show(this, '当前专辑时长未知，无法设置');
      }
    } else if (index === 5) {
      SleepTimerService.cancel();
      ToastUtil.show(this, '已关闭定时关闭');
    }
  }

  private playbackSettingsMenuItems(): TagButtonMenuItem[] {
    return [
      {
        value: `${this.playback.mode === 'listLoop' ? '✓ ' : ''}列表循环`,
        action: (): void => {
          PlaybackService.setPlaybackMode('listLoop');
          ToastUtil.show(this, '列表循环');
        }
      },
      {
        value: `${this.playback.mode === 'singleLoop' ? '✓ ' : ''}单曲循环`,
        action: (): void => {
          PlaybackService.setPlaybackMode('singleLoop');
          ToastUtil.show(this, '单曲循环');
        }
      },
      {
        value: `${this.playback.mode === 'random' ? '✓ ' : ''}随机播放`,
        action: (): void => {
          PlaybackService.setPlaybackMode('random');
          ToastUtil.show(this, '随机播放');
        }
      },
      {
        value: `定时关闭：${SleepTimerService.label()}`,
        action: (): void => {
          void this.openSleepTimerMenu();
        }
      },
      {
        value: this.showLyrics ? '返回封面' : '显示歌词',
        action: (): void => {
          this.setLyricsVisible(!this.showLyrics);
        }
      },
      {
        value: this.showLyricAdjust ? '收起歌词校准' : '打开歌词校准',
        action: (): void => {
          this.setLyricsVisible(true);
          this.showLyricAdjust = !this.showLyricAdjust;
        }
      },
      {
        value: `歌词提前 0.5 秒（${this.lyricVm.getOffsetText()}）`,
        action: (): void => {
          this.onOffsetDecrease();
        }
      },
      {
        value: `歌词延后 0.5 秒（${this.lyricVm.getOffsetText()}）`,
        action: (): void => {
          this.onOffsetIncrease();
        }
      },
      {
        value: '重新同步歌词',
        action: (): void => {
          void this.refreshLyricsFromMusicTagWeb();
        }
      },
      {
        value: '保存当前歌词到 Music Tag Web',
        action: (): void => {
          void this.saveCurrentLyrics();
        }
      },
      {
        value: '在 Music Tag Web 打开元数据详情',
        action: (): void => {
          this.openMetadataDetail();
        }
      },
      {
        value: '重置歌词校准',
        action: (): void => {
          this.onOffsetReset();
        }
      }
    ];
  }

  private trackTitle(): string {
    return this.playback.track?.title ?? '未播放';
  }

  private trackArtist(): string {
    return this.playback.track?.artist ?? '选择一首歌曲开始播放';
  }

  private trackAlbum(): string {
    return this.playback.track?.album ?? '';
  }

  private durationMs(): number {
    return this.playback.track?.durationMs ?? 0;
  }

  private phaseText(): string {
    if (this.showLyrics) {
      if (this.lyricVm.loadState === 'loading') {
        return '正在同步歌词';
      }
      if (this.lyricVm.loadState === 'loaded') {
        return `歌词来源 · ${this.lyricVm.sourceLabel()}`;
      }
      if (this.lyricVm.loadState === 'notFound') {
        return '暂无歌词';
      }
      if (this.lyricVm.loadState === 'error') {
        return '歌词同步失败';
      }
    }
    if (this.playback.isBuffering) {
      return '缓冲中';
    }
    if (this.playback.phase === 'loading') {
      return '加载中';
    }
    if (this.playback.phase === 'playing') {
      return '正在播放';
    }
    if (this.playback.phase === 'paused') {
      return '已暂停';
    }
    if (this.playback.phase === 'error') {
      return '播放失败';
    }
    return '等待播放';
  }

  private coverSize(): number {
    const widthSize: number = Math.min(this.containerWidth * 0.66, 300);
    const heightSize: number = Math.max(160, this.containerHeight * 0.32);
    return Math.min(widthSize, heightSize);
  }

  private fullscreenLyricHeight(): number {
    const reservedHeight: number = this.showLyricAdjust ? 342 : 278;
    return Math.max(180, this.containerHeight - this.topInset - this.bottomInset - reservedHeight);
  }

  @Builder
  private buildTopBar() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([UiTokens.COLOR_TEXT_PRIMARY])
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor(UiTokens.COLOR_CARD_BG)
      .accessibilityText('返回')
      .onClick(() => {
        this.onBackTap();
      })

      Column({ space: 2 }) {
        Text(this.showLyrics ? '歌词' : '正在播放')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(this.phaseText())
          .fontSize(11)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column()
      .width(48)
      .height(48)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildTrackInfo(compact: boolean) {
    Row() {
      Column({ space: compact ? 3 : 5 }) {
        Text(this.trackTitle())
          .fontSize(compact ? 20 : 24)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.trackArtist())
          .fontSize(compact ? 14 : 16)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (!compact && this.trackAlbum().length > 0) {
          Text(this.trackAlbum())
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button() {
        Image(this.isFavorite ? $r('app.media.ic_heart_filled') : $r('app.media.ic_heart'))
          .width(22)
          .height(22)
          .fillColor(this.isFavorite ? UiTokens.COLOR_PRIMARY : UiTokens.COLOR_TEXT_SECONDARY)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(Color.Transparent)
      .enabled(!this.favoriteLoading && this.playback.track !== null)
      .accessibilityText(this.isFavorite ? '取消喜爱' : '添加到喜爱')
      .onClick(() => {
        void this.toggleFavorite();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 24, right: 18, top: compact ? 4 : 8, bottom: compact ? 6 : 8 })
  }

  @Builder
  private buildProgress() {
    Column({ space: 0 }) {
      OuterScreenProgressBar({
        barWidth: this.containerWidth - 24
      })

      Row() {
        Text(this.formatTime(this.lastPositionMs))
          .fontSize(11)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
        Blank()
        Text(this.formatTime(this.durationMs()))
          .fontSize(11)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildPrimaryControls() {
    Row() {
      Button() {
        Image($r('app.media.ic_playback_settings'))
          .width(21)
          .height(21)
          .fillColor(UiTokens.COLOR_TEXT_SECONDARY)
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(Color.Transparent)
      .accessibilityText(`播放设置，当前${this.getModeText(this.playback.mode)}`)
      .bindMenu(this.playbackSettingsMenuItems())

      Button() {
        Image($r('app.media.cb_prev'))
          .width(27)
          .height(27)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor(Color.Transparent)
      .accessibilityText('上一首')
      .onClick(() => {
        this.onPreviousTap();
      })

      Button() {
        Image(this.playback.isPlaying() ? $r('app.media.cb_pause') : $r('app.media.cb_play'))
          .width(32)
          .height(32)
          .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(UiTokens.COLOR_PRIMARY)
      .shadow({ radius: 12, color: '#40000000', offsetX: 0, offsetY: 4 })
      .accessibilityText(this.playback.isPlaying() ? '暂停' : '播放')
      .onClick(() => {
        this.onPlayPauseTap();
      })

      Button() {
        Image($r('app.media.cb_next'))
          .width(27)
          .height(27)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor(Color.Transparent)
      .accessibilityText('下一首')
      .onClick(() => {
        this.onNextTap();
      })

      Button() {
        Image($r('app.media.cb_queue'))
          .width(21)
          .height(21)
          .fillColor(UiTokens.COLOR_TEXT_SECONDARY)
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(Color.Transparent)
      .accessibilityText('播放队列')
      .onClick(() => {
        this.onQueueTap();
      })
    }
    .width('100%')
    .height(76)
    .padding({ left: 18, right: 18 })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildLyricAdjustPanel() {
    Row() {
      Button('-')
        .width(48)
        .height(40)
        .fontSize(20)
        .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        .borderRadius(20)
        .backgroundColor(UiTokens.COLOR_CARD_BG)
        .onClick(() => {
          this.onOffsetDecrease();
        })

      Column({ space: 1 }) {
        Text(this.lyricVm.getOffsetText())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text('歌词偏移')
          .fontSize(10)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .width(90)
      .alignItems(HorizontalAlign.Center)

      Button('+')
        .width(48)
        .height(40)
        .fontSize(20)
        .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        .borderRadius(20)
        .backgroundColor(UiTokens.COLOR_CARD_BG)
        .onClick(() => {
          this.onOffsetIncrease();
        })

      Button('重置')
        .width(58)
        .height(40)
        .fontSize(12)
        .fontColor(UiTokens.COLOR_PRIMARY)
        .borderRadius(20)
        .backgroundColor(UiTokens.COLOR_CARD_BG)
        .onClick(() => {
          this.onOffsetReset();
        })
    }
    .width('100%')
    .height(54)
    .padding({ left: 24, right: 24 })
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildCoverMode() {
    Column() {
      Column() {
        OuterScreenCoverStack({ discSize: this.coverSize() })
      }
      .width('100%')
      .height(this.coverSize() + 8)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      this.buildTrackInfo(false)

      LyricView({
        lines: this.lyricVm.lines,
        currentLineIndex: this.lyricVm.currentLineIndex,
        visible: this.lyricVm.hasLyrics(),
        viewHeight: 78,
        lineHeight: 30,
        activeFontSize: 16,
        inactiveFontSize: 13,
        activeColor: UiTokens.COLOR_PRIMARY,
        inactiveColor: UiTokens.COLOR_TEXT_SECONDARY,
        isLoading: this.lyricVm.loadState === 'loading',
        hasLyrics: this.lyricVm.hasLyrics(),
        isFullscreen: false,
        isActive: !this.showLyrics,
        onLineClick: (_lineIndex: number, _timeMs: number) => {
          this.toggleLyrics();
        }
      })
        .width('100%')
        .height(78)

      this.buildProgress()
      this.buildPrimaryControls()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.SpaceBetween)
    .transition(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: -24 }))
        .animation({ duration: 260, curve: Curve.EaseInOut })
    )
  }

  @Builder
  private buildLyricsMode() {
    Column() {
      this.buildTrackInfo(true)

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
        isLoading: this.lyricVm.loadState === 'loading',
        hasLyrics: this.lyricVm.hasLyrics(),
        isFullscreen: true,
        isActive: this.showLyrics,
        onLineClick: (lineIndex: number, timeMs: number) => {
          this.onLyricLineClick(lineIndex, timeMs);
        }
      })
        .width('100%')
        .height(this.fullscreenLyricHeight())

      if (this.showLyricAdjust) {
        this.buildLyricAdjustPanel()
      }

      this.buildProgress()
      this.buildPrimaryControls()
    }
    .width('100%')
    .layoutWeight(1)
    .transition(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: 58 }))
        .animation({ duration: 300, curve: Curve.EaseOut })
    )
  }

  build() {
    Stack() {
      GlobalPageBackground()
      Column() {
        Column()
          .width('100%')
          .height(this.topInset)

        this.buildTopBar()

        if (this.showLyrics) {
          this.buildLyricsMode()
        } else {
          this.buildCoverMode()
        }

        Column()
          .width('100%')
          .height(this.bottomInset)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      if (newValue.width !== undefined) {
        this.containerWidth = Math.floor(Number(newValue.width));
      }
      if (newValue.height !== undefined) {
        this.containerHeight = Math.floor(Number(newValue.height));
      }
    })
  }
}
