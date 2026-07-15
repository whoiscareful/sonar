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

const COVER_SIZE: number = 44;
const COVER_RADIUS: number = 8;
const ARTIST_FONT_SIZE: number = 11;
const META_FONT_SIZE: number = 11;
const TAP_MOVE_CANCEL_DISTANCE: number = 3;

/**
 * 音乐歌曲行组件，用于 LazyForEach 懒加载。
 * 支持专辑封面、标题、歌手、时长、更多菜单等功能。
 */
@Reusable
@Component
export struct MusicSongRow {
  @Prop song: Song = { id: '', parent: '', isDir: false, title: '', artist: '', album: '', size: 0, duration: 0 };
  @Prop index: number = 0;
  @Prop songs: Song[] = [];
  @Prop highlightSongId: string = '';
  @Prop playingTrackId: string = '';
  @Prop playbackPhase: PlaybackPhase = 'idle';
  @Prop showArtist: boolean = true;
  @Prop showAlbumCover: boolean = true;
  @Prop albumCoverArtId: string = '';
  @Prop showRemoveFromRecent: boolean = false;
  @Prop enableLongPressSelection: boolean = false;
  @Prop selectionMode: boolean = false;
  @Prop selected: boolean = false;
  @BuilderParam onLongPressSelection: (song: Song) => void;
  @BuilderParam onSelectionToggle: (song: Song) => void;
  @State private touchStartX: number = 0;
  @State private touchStartY: number = 0;
  @State private touchMoved: boolean = false;
  @State private longPressTriggered: boolean = false;

  private isHighlighted(): boolean {
    return this.highlightSongId.length > 0 && this.song.id === this.highlightSongId;
  }

  private isNowPlaying(): boolean {
    return this.playingTrackId.length > 0 &&
      this.song.id === this.playingTrackId &&
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

  private trailingMetaText(): string {
    if (this.isNowPlaying()) {
      return '正在播放';
    }
    return this.formatDurationSeconds(this.song.duration);
  }

  private resolveCoverArtId(): string {
    if (this.song.coverArt !== undefined && this.song.coverArt.length > 0) {
      return this.song.coverArt;
    }
    return this.albumCoverArtId;
  }

  private handleItemClick(): void {
    if (this.longPressTriggered) {
      this.longPressTriggered = false;
      return;
    }
    if (this.touchMoved) {
      this.touchMoved = false;
      return;
    }
    if (this.selectionMode) {
      this.onSelectionToggle(this.song);
      return;
    }
    const coverArt: string = this.resolveCoverArtId();
    void PlaybackService.playQueue(this.songs, this.index, coverArt).then(() => {
      PlaybackService.setPlaybackMode('listLoop');
    });
  }

  private handleItemLongPress(): void {
    if (!this.enableLongPressSelection) {
      return;
    }
    this.longPressTriggered = true;
    this.onLongPressSelection(this.song);
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

  private showToast(message: string): void {
    ToastUtil.show(this, message);
  }

  private openMetadataDetail(): void {
    if (this.song.path === undefined || this.song.path.length === 0) {
      this.showToast('当前歌曲缺少文件路径，无法打开详情');
      return;
    }
    const url: string = MusicTagWebOpenApiClient.getInstance().metadataDetailUrl(this.song.path);
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

  private buildAlbumMenuItems(): TagButtonMenuItem[] {
    return [
      {
        value: this.song.starred !== undefined && this.song.starred.length > 0 ? '取消喜爱' : '添加到喜爱',
        action: (): void => {
          void MusicViewModel.getInstance().toggleFavorite(this.song).then((favorite: boolean) => {
            this.showToast(favorite ? `已添加到喜爱：${this.song.title}` : `已从喜爱移除：${this.song.title}`);
          }).catch((err: Error) => {
            this.showToast(`同步失败：${err.message}`);
          });
        }
      },
      {
        value: '添加到播放列表',
        action: (): void => {
          void this.appendSongToPlaybackQueue();
        }
      },
      {
        value: '添加到我的歌单',
        action: (): void => {
          void this.addSongToUserPlaylist();
        }
      },
      {
        value: '下载',
        action: (): void => {
          if (SongCache.isComplete(this.song.id)) {
            this.showToast(`已在缓存中：${this.song.title}`);
          } else {
            void SongCache.enqueueDownload(this.song.id);
            this.showToast(`已加入下载：${this.song.title}`);
          }
        }
      },
      {
        value: '详情',
        action: (): void => {
          this.openMetadataDetail();
        }
      }
    ];
  }

  private async appendSongToPlaybackQueue(): Promise<void> {
    const added: number = await PlaybackService.appendToPlaylist([this.song]);
    this.showToast(added > 0 ? `已添加到播放列表：${this.song.title}` : `已在播放列表中：${this.song.title}`);
  }

  private async addSongToUserPlaylist(): Promise<void> {
    try {
      const result: AddToUserPlaylistResult = await UserPlaylistPicker.addSong(this.getUIContext(), this.song);
      if (result.message !== '已取消') {
        this.showToast(result.message);
      }
    } catch (err) {
      this.showToast(`添加失败：${(err as Error).message}`);
    }
  }

  private menuItemsFor(): TagButtonMenuItem[] {
    const items: TagButtonMenuItem[] = this.buildAlbumMenuItems();
    if (this.showRemoveFromRecent) {
      items.push({
        value: '移除',
        action: (): void => {
          void MusicViewModel.getInstance().removeFromRecent(this.song.id);
          this.showToast(`已从最近播放移除：${this.song.title}`);
        }
      });
    }
    return items;
  }

  build() {
    Row() {
      // 封面
      if (this.selectionMode) {
        Checkbox({ name: `music-song-${this.song.id}`, group: 'music-song-selection' })
          .select(this.selected)
          .selectedColor(UiTokens.COLOR_PRIMARY)
          .width(26)
          .height(26)
          .margin({ right: 12 })
          .hitTestBehavior(HitTestMode.None)
      } else if (this.showAlbumCover) {
        Image(CoverDisplayResolver.resolve(this.resolveCoverArtId(), COVER_SIZE))
          .width(COVER_SIZE)
          .height(COVER_SIZE)
          .borderRadius(COVER_RADIUS)
          .objectFit(ImageFit.Cover)
          .alt('#E5E5EA')
      }

      // 标题和歌手
      AutoMarqueeText({
        text: this.song.title,
        fontSize: 14,
        fontWeight: this.isHighlighted() ? FontWeight.Bold : FontWeight.Medium,
        fontColor: this.isHighlighted() ?
          UiTokens.COLOR_PRIMARY : UiTokens.COLOR_TEXT_PRIMARY,
        secondaryText: this.showArtist ?
          (this.song.artist.length > 0 ? this.song.artist : '未知歌手') : '',
        secondaryFontSize: ARTIST_FONT_SIZE,
        secondaryFontColor: UiTokens.COLOR_MUSIC_ARTIST,
        secondaryGapVp: 6
      })
        .layoutWeight(1)
        .height(UiTokens.MUSIC_LIST_TITLE_HEIGHT)
        .flexShrink(1)
        .margin({ right: UiTokens.MUSIC_LIST_TEXT_TRAILING_GAP })

      // 时长/状态
      if (!this.selectionMode) {
        Text(this.trailingMetaText())
          .fontSize(META_FONT_SIZE)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          .maxLines(1)
          .flexShrink(0)
          .margin({ right: 4 })
      }

      // 更多菜单
      if (!this.selectionMode) {
        MoreMenuIconButton({
          menuItems: this.menuItemsFor(),
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
    .onClick(() => this.handleItemClick())
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          this.handleItemLongPress();
        })
    )
  }
}
