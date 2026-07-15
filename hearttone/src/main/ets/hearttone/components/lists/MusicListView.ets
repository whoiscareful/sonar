import { common, Want } from '@kit.AbilityKit';
import { Song } from '../../api/SubsonicTypes';
import { CoverDisplayResolver } from '../../cache/CoverDisplayResolver';
import { SongCache } from '../../cache/SongCache';
import { TagButtonMenuItem } from '../buttons/TagButton';
import { MoreMenuIconButton } from '../buttons/MoreMenuIconButton';
import { AutoMarqueeText } from '../layout/AutoMarqueeText';
import { ToastUtil } from '../../common/ToastUtil';
import { PlaybackService } from '../../playback/PlaybackService';
import { PlaybackPhase } from '../../playback/PlaybackSnapshot';
import { MusicViewModel } from '../../viewmodel/MusicViewModel';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { MusicTagWebOpenApiClient } from '../../enhanced/MusicTagWebOpenApiClient';
import { AddToUserPlaylistResult, UserPlaylistPicker } from '../../domain/playlist/UserPlaylistPicker';

export type MusicListVariant = 'album' | 'browse';

const MUSIC_LIST_COVER_SIZE: number = 44;
const MUSIC_LIST_COVER_RADIUS: number = 8;
const TAP_MOVE_CANCEL_DISTANCE: number = 3;

@Component
struct MusicListCoverThumb {
  @Prop coverArtId: string = '';
  @StorageLink('coverCacheRevision') coverCacheRevision: number = 0;

  build() {
    if (this.coverArtId.length === 0) {
      Column() {
        Text('♪')
          .fontSize(18)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .width(MUSIC_LIST_COVER_SIZE)
      .height(MUSIC_LIST_COVER_SIZE)
      .borderRadius(MUSIC_LIST_COVER_RADIUS)
      .backgroundColor(UiTokens.COLOR_CARD_BORDER)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .flexShrink(0)
      .margin({ right: 12 })
    } else {
      Image(CoverDisplayResolver.resolve(this.coverArtId, 120) ?? '')
        .width(MUSIC_LIST_COVER_SIZE)
        .height(MUSIC_LIST_COVER_SIZE)
        .borderRadius(MUSIC_LIST_COVER_RADIUS)
        .objectFit(ImageFit.Cover)
        .flexShrink(0)
        .margin({ right: 12 })
        .onVisibleAreaChange([0.0, 1.0], (visible: boolean, ratio: number) => {
          if (visible && ratio >= 1.0) {
            CoverDisplayResolver.enqueueWhenVisible(this.coverArtId);
          }
        })
    }
  }
}

@Reusable
@Component
export struct MusicListRow {
  @Prop song: Song = MusicListRow.emptySong();
  @Prop index: number = 0;
  @Prop highlightSongId: string = '';
  @Prop playingTrackId: string = '';
  @Prop playbackPhase: PlaybackPhase = 'idle';
  @Prop showArtist: boolean = false;
  @Prop isLast: boolean = false;
  @State private touchStartX: number = 0;
  @State private touchStartY: number = 0;
  @State private touchMoved: boolean = false;

  private static emptySong(): Song {
    return {
      id: '',
      parent: '',
      isDir: false,
      title: '',
      album: '',
      artist: '',
      size: 0,
      duration: 0
    };
  }

  private isHighlighted(): boolean {
    return this.highlightSongId.length > 0 && this.song.id === this.highlightSongId;
  }

  private isCurrentTrack(): boolean {
    return this.playingTrackId.length > 0 && this.song.id === this.playingTrackId;
  }

  private formatDurationSeconds(seconds: number): string {
    if (seconds <= 0) {
      return '--:--';
    }
    const totalSeconds: number = Math.floor(seconds);
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor((totalSeconds % 3600) / 60);
    const remainSeconds: number = totalSeconds % 60;
    const paddedMinutes: string = minutes < 10 ? `0${minutes}` : `${minutes}`;
    const paddedSeconds: string = remainSeconds < 10 ? `0${remainSeconds}` : `${remainSeconds}`;
    if (hours > 0) {
      return `${hours}:${paddedMinutes}:${paddedSeconds}`;
    }
    return `${minutes}:${paddedSeconds}`;
  }

  private trailingMetaText(): string {
    if (this.isCurrentTrack()) {
      if (this.playbackPhase === 'playing') {
        return '正在播放';
      }
      if (this.playbackPhase === 'loading') {
        return '加载中';
      }
      if (this.playbackPhase === 'error') {
        return '播放失败';
      }
      return '已暂停';
    }
    return this.formatDurationSeconds(this.song.duration);
  }

  private handleRowClick(): void {
    if (this.touchMoved) {
      this.touchMoved = false;
      return;
    }
    if (this.isCurrentTrack()) {
      if (this.playbackPhase === 'playing' || this.playbackPhase === 'paused') {
        void PlaybackService.toggle();
      } else if (this.playbackPhase === 'idle' || this.playbackPhase === 'error') {
        void PlaybackService.playFromPlaylistIndex(this.index);
      }
      return;
    }
    void PlaybackService.playFromPlaylistIndex(this.index);
  }

  private async removeSong(): Promise<void> {
    const index: number = this.index;
    const title: string = this.song.title;
    try {
      await PlaybackService.removeFromPlaylist(index);
      ToastUtil.show(this, `已从播放列表移除：${title}`, 1600);
    } catch (err) {
      ToastUtil.show(this, `移除失败：${(err as Error).message}`, 1800);
    }
  }

  private handleTouch(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }
    const x: number = event.touches[0].x;
    const y: number = event.touches[0].y;
    if (event.type === TouchType.Down) {
      this.touchStartX = x;
      this.touchStartY = y;
      this.touchMoved = false;
      return;
    }
    if (event.type === TouchType.Move) {
      const dx: number = Math.abs(x - this.touchStartX);
      const dy: number = Math.abs(y - this.touchStartY);
      if (dx > TAP_MOVE_CANCEL_DISTANCE || dy > TAP_MOVE_CANCEL_DISTANCE) {
        this.touchMoved = true;
      }
      return;
    }
    if (event.type === TouchType.Cancel) {
      this.touchMoved = true;
    }
  }

  @Builder
  private buildDivider() {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(UiTokens.COLOR_CARD_BORDER)
      .opacity(0.45)
  }

  @Builder
  private buildSwipeDelete() {
    Row() {
      Text('删除')
        .fontSize(14)
        .fontColor(Color.White)
    }
    .width(72)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(UiTokens.COLOR_DANGER)
    .onClick(() => {
      void this.removeSong();
    })
  }

  build() {
    ListItem() {
      Column() {
        Row() {
          AutoMarqueeText({
            text: this.song.title,
            fontSize: 14,
            fontWeight: this.isHighlighted() ? FontWeight.Bold : FontWeight.Medium,
            fontColor: this.isHighlighted() ? UiTokens.COLOR_PRIMARY : UiTokens.COLOR_TEXT_PRIMARY,
            secondaryText: this.showArtist ?
              (this.song.artist.length > 0 ? this.song.artist : '未知歌手') : '',
            secondaryFontSize: 11,
            secondaryFontColor: UiTokens.COLOR_MUSIC_ARTIST,
            secondaryGapVp: 6
          })
            .layoutWeight(1)
            .height(UiTokens.MUSIC_LIST_TITLE_HEIGHT)
            .flexShrink(1)
            .margin({ right: UiTokens.MUSIC_LIST_TEXT_TRAILING_GAP })

          Text(this.trailingMetaText())
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
            .maxLines(1)
            .flexShrink(0)
        }
        .width('100%')
        .padding({ top: 14, bottom: 14 })
        .alignItems(VerticalAlign.Center)
        .onTouch((event: TouchEvent) => {
          this.handleTouch(event);
        })
        .onClick(() => {
          this.handleRowClick();
        })

        if (!this.isLast) {
          this.buildDivider()
        }
      }
      .width('100%')
    }
    .swipeAction({
      end: {
        builder: (): void => {
          this.buildSwipeDelete();
        }
      }
    })
  }
}

@Component
export struct MusicListView {
  @Prop songs: Song[] = [];
  @Prop highlightSongId: string = '';
  @Prop playingTrackId: string = '';
  @Prop playbackPhase: PlaybackPhase = 'idle';
  @Prop listVariant: MusicListVariant = 'album';
  @Prop showArtist: boolean = false;
  @Prop showAlbumCover: boolean = false;
  @Prop albumCoverArtId: string = '';
  @Prop showRemoveFromRecent: boolean = false;
  @Prop enableLongPressSelection: boolean = false;
  @Prop selectionMode: boolean = false;
  @Prop selectedSongIds: string[] = [];
  @BuilderParam onLongPressSelection: (song: Song) => void;
  @BuilderParam onSelectionToggle: (song: Song) => void;
  @State private touchStartX: number = 0;
  @State private touchStartY: number = 0;
  @State private touchMoved: boolean = false;
  @State private longPressedSongId: string = '';

  private static readonly COVER_SIZE: number = MUSIC_LIST_COVER_SIZE;
  private static readonly COVER_RADIUS: number = MUSIC_LIST_COVER_RADIUS;
  private static readonly ARTIST_FONT_SIZE: number = 11;
  private static readonly META_FONT_SIZE: number = 11;

  private isHighlighted(song: Song): boolean {
    return this.highlightSongId.length > 0 && song.id === this.highlightSongId;
  }

  private isNowPlaying(song: Song): boolean {
    return this.playingTrackId.length > 0 &&
      song.id === this.playingTrackId &&
      this.playbackPhase === 'playing';
  }

  private formatDurationSeconds(seconds: number): string {
    if (seconds <= 0) {
      return '--:--';
    }
    const totalSeconds: number = Math.floor(seconds);
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor((totalSeconds % 3600) / 60);
    const remainSeconds: number = totalSeconds % 60;
    const paddedMinutes: string = minutes < 10 ? `0${minutes}` : `${minutes}`;
    const paddedSeconds: string = remainSeconds < 10 ? `0${remainSeconds}` : `${remainSeconds}`;
    if (hours > 0) {
      return `${hours}:${paddedMinutes}:${paddedSeconds}`;
    }
    return `${minutes}:${paddedSeconds}`;
  }

  private trailingMetaText(song: Song): string {
    if (this.isNowPlaying(song)) {
      return '正在播放';
    }
    return this.formatDurationSeconds(song.duration);
  }

  private showToast(message: string): void {
    ToastUtil.show(this, message, 1600);
  }

  private isSelected(song: Song): boolean {
    return this.selectedSongIds.indexOf(song.id) >= 0;
  }

  private openMetadataDetail(song: Song): void {
    if (song.path === undefined || song.path.length === 0) {
      this.showToast('当前歌曲缺少文件路径，无法打开详情');
      return;
    }
    const url: string = MusicTagWebOpenApiClient.getInstance().metadataDetailUrl(song.path);
    if (url.length === 0) {
      this.showToast('请先登录服务器');
      return;
    }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: url
    };
    void context.startAbility(want).catch((err: Error) => {
      this.showToast(`打开详情失败：${err.message}`);
    });
  }

  private buildAlbumMenuItems(song: Song): TagButtonMenuItem[] {
    return [
      {
        value: '下一首播放',
        action: (): void => {
          void this.enqueueSongNext(song);
        }
      },
      {
        value: '添加到播放列表',
        action: (): void => {
          void this.appendSongToPlaylist(song);
        }
      },
      {
        value: '添加到我的歌单',
        action: (): void => {
          void this.addSongToUserPlaylist(song);
        }
      },
      {
        value: '下载',
        action: (): void => {
          if (SongCache.isComplete(song.id)) {
            this.showToast(`已在缓存中：${song.title}`);
          } else {
            void SongCache.enqueueDownload(song.id);
            this.showToast(`已加入下载：${song.title}`);
          }
        }
      },
      {
        value: '详情',
        action: (): void => {
          this.openMetadataDetail(song);
        }
      }
    ];
  }

  private async appendSongToPlaylist(song: Song): Promise<void> {
    const added: number = await PlaybackService.appendToPlaylist([song]);
    if (added > 0) {
      this.showToast(`已添加到播放列表：${song.title}`);
    } else {
      this.showToast(`已在播放列表中：${song.title}`);
    }
  }

  private async addSongToUserPlaylist(song: Song): Promise<void> {
    try {
      const result: AddToUserPlaylistResult = await UserPlaylistPicker.addSong(this.getUIContext(), song);
      this.showToast(result.message);
    } catch (err) {
      this.showToast(`添加失败：${(err as Error).message}`);
    }
  }

  private async enqueueSongNext(song: Song): Promise<void> {
    try {
      const result = await PlaybackService.enqueueNext(song);
      if (result === 'started') {
        this.showToast(`已开始播放：${song.title}`);
      } else if (result === 'moved') {
        this.showToast(`已移到下一首：${song.title}`);
      } else if (result === 'alreadyNext') {
        this.showToast(`已经是下一首：${song.title}`);
      } else if (result === 'current') {
        this.showToast(`正在播放：${song.title}`);
      } else {
        this.showToast(`已加入下一首：${song.title}`);
      }
    } catch (err) {
      this.showToast(`操作失败：${(err as Error).message}`);
    }
  }

  private menuItemsFor(song: Song): TagButtonMenuItem[] {
    const items: TagButtonMenuItem[] = this.buildAlbumMenuItems(song);
    if (this.showRemoveFromRecent) {
      items.push({
        value: '移除',
        action: (): void => {
          void MusicViewModel.getInstance().removeFromRecent(song.id);
          this.showToast(`已从最近播放移除：${song.title}`);
        }
      });
    }
    return items;
  }

  private hasMoreMenu(): boolean {
    return this.listVariant === 'album' || this.listVariant === 'browse';
  }

  private resolveCoverArtId(song: Song): string {
    if (song.coverArt !== undefined && song.coverArt.length > 0) {
      return song.coverArt;
    }
    return this.albumCoverArtId;
  }

  private handleItemClick(index: number, song: Song): void {
    if (this.longPressedSongId === song.id) {
      this.longPressedSongId = '';
      return;
    }
    if (this.touchMoved) {
      this.touchMoved = false;
      return;
    }
    if (this.selectionMode) {
      this.onSelectionToggle(song);
      return;
    }
    if (this.listVariant === 'album' || this.listVariant === 'browse') {
      const coverArt: string = this.listVariant === 'browse' ?
        this.resolveCoverArtId(song) : this.albumCoverArtId;
      void PlaybackService.playQueue(this.songs, index, coverArt).then(() => {
        PlaybackService.setPlaybackMode('listLoop');
      });
    }
  }

  private handleItemLongPress(song: Song): void {
    if (!this.enableLongPressSelection) {
      return;
    }
    this.longPressedSongId = song.id;
    this.onLongPressSelection(song);
  }

  private handleTouch(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }
    const x: number = event.touches[0].x;
    const y: number = event.touches[0].y;
    if (event.type === TouchType.Down) {
      this.touchStartX = x;
      this.touchStartY = y;
      this.touchMoved = false;
      return;
    }
    if (event.type === TouchType.Move) {
      const dx: number = Math.abs(x - this.touchStartX);
      const dy: number = Math.abs(y - this.touchStartY);
      if (dx > TAP_MOVE_CANCEL_DISTANCE || dy > TAP_MOVE_CANCEL_DISTANCE) {
        this.touchMoved = true;
      }
      return;
    }
    if (event.type === TouchType.Cancel) {
      this.touchMoved = true;
    }
  }

  @Builder
  private buildDivider() {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(UiTokens.COLOR_CARD_BORDER)
      .opacity(0.45)
  }

  @Builder
  private buildAlbumCoverThumb(song: Song) {
    if (this.selectionMode) {
      Checkbox({ name: `playlist-song-${song.id}`, group: 'playlist-song-selection' })
        .select(this.isSelected(song))
        .selectedColor(UiTokens.COLOR_PRIMARY)
        .width(26)
        .height(26)
        .margin({ right: 12 })
        .hitTestBehavior(HitTestMode.None)
    } else if (this.showAlbumCover || this.listVariant === 'browse') {
      MusicListCoverThumb({ coverArtId: this.resolveCoverArtId(song) })
    }
  }

  @Builder
  private buildTitleBlock(song: Song) {
    AutoMarqueeText({
      text: song.title,
      fontSize: 14,
      fontWeight: this.isHighlighted(song) ? FontWeight.Bold : FontWeight.Medium,
      fontColor: this.isHighlighted(song) ?
        UiTokens.COLOR_PRIMARY : UiTokens.COLOR_TEXT_PRIMARY,
      secondaryText: this.showArtist ?
        (song.artist.length > 0 ? song.artist : '未知歌手') : '',
      secondaryFontSize: MusicListView.ARTIST_FONT_SIZE,
      secondaryFontColor: UiTokens.COLOR_MUSIC_ARTIST,
      secondaryGapVp: 6
    })
      .layoutWeight(1)
      .height(UiTokens.MUSIC_LIST_TITLE_HEIGHT)
      .flexShrink(1)
      .margin({ right: UiTokens.MUSIC_LIST_TEXT_TRAILING_GAP })
  }

  build() {
    Column() {
      ForEach(this.songs, (song: Song, index: number) => {
        Column() {
          Row() {
            this.buildAlbumCoverThumb(song)
            this.buildTitleBlock(song)

            Text(this.trailingMetaText(song))
              .fontSize(MusicListView.META_FONT_SIZE)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
              .maxLines(1)
              .flexShrink(0)
              .margin({ right: 4 })

            if (!this.selectionMode && this.hasMoreMenu()) {
              MoreMenuIconButton({
                menuItems: this.menuItemsFor(song),
                useDarkOverlay: false
              })
                .flexShrink(0)
            }
          }
          .width('100%')
          .padding({ top: 14, bottom: 14 })
          .alignItems(VerticalAlign.Center)
          .onTouch((event: TouchEvent) => {
            this.handleTouch(event);
          })
          .onClick(() => {
            this.handleItemClick(index, song);
          })
          .gesture(
            LongPressGesture({ repeat: false, duration: 500 })
              .onAction(() => {
                this.handleItemLongPress(song);
              })
          )

          if (index < this.songs.length - 1) {
            this.buildDivider()
          }
        }
        .width('100%')
      }, (song: Song, index: number) => `${index}_${song.id}`)
    }
    .width('100%')
  }
}
