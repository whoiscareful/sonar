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

const COVER_SIZE: number = 44;
const COVER_RADIUS: number = 8;
const ARTIST_FONT_SIZE: number = 11;
const META_FONT_SIZE: number = 11;

/**
 * 音乐歌曲行组件，用于 LazyForEach 懒加载。
 * 支持专辑封面、标题、歌手、时长、更多菜单等功能。
 */
@Reusable
@Component
export struct MusicSongRow {
  @Prop song: Song = { id: '', title: '', artist: '', album: '', albumId: '' };
  @Prop index: number = 0;
  @Prop songs: Song[] = [];
  @Prop highlightSongId: string = '';
  @Prop playingTrackId: string = '';
  @Prop playbackPhase: PlaybackPhase = 'idle';
  @Prop showArtist: boolean = true;
  @Prop showAlbumCover: boolean = true;
  @Prop albumCoverArtId: string = '';
  @Prop showRemoveFromRecent: boolean = false;

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
    const coverArt: string = this.resolveCoverArtId();
    void PlaybackService.playQueue(this.songs, this.index, coverArt).then(() => {
      PlaybackService.setPlaybackMode('listLoop');
    });
  }

  private showToast(message: string): void {
    ToastUtil.show(message);
  }

  private async appendSongToPlaylist(song: Song): Promise<void> {
    try {
      await MusicViewModel.getInstance().appendToPlaylist(song);
      this.showToast(`已添加到播放列表：${song.title}`);
    } catch (err) {
      const message: string = (err as Error).message;
      this.showToast(message.length > 0 ? message : '添加失败');
    }
  }

  private buildAlbumMenuItems(): TagButtonMenuItem[] {
    return [
      {
        value: '添加到播放列表',
        action: (): void => {
          void this.appendSongToPlaylist(this.song);
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
          this.showToast('功能开发中');
        }
      }
    ];
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
      if (this.showAlbumCover) {
        Image(CoverDisplayResolver.resolve(this.resolveCoverArtId()))
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
      Text(this.trailingMetaText())
        .fontSize(META_FONT_SIZE)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
        .maxLines(1)
        .flexShrink(0)
        .margin({ right: 4 })

      // 更多菜单
      MoreMenuIconButton({
        menuItems: this.menuItemsFor(),
        useDarkOverlay: false
      })
        .flexShrink(0)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.handleItemClick())
  }
}
