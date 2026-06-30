import { AlbumDetailRouteParam } from '../api/SubsonicTypes';
import { AlbumDetailViewModel } from '../viewmodel/AlbumDetailViewModel';
import { CoverDisplayResolver } from '../cache/CoverDisplayResolver';
import { LoadingState } from '../components/feedback/LoadingState';
import { ErrorState } from '../components/feedback/ErrorState';
import { MoreMenuIconButton } from '../components/buttons/MoreMenuIconButton';
import { MusicListView } from '../components/lists/MusicListView';
import { SecondaryHdsDestination } from '../components/navigation/SecondaryHdsDestination';
import { UiTokens } from '../ui/tokens/UiTokens';
import { ToastUtil } from '../common/ToastUtil';
import { PlaybackService } from '../playback/PlaybackService';
import { PlaybackPhase } from '../playback/PlaybackSnapshot';

@Component
export struct AlbumDetailPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State vm: AlbumDetailViewModel = new AlbumDetailViewModel();
  @StorageLink('playbackTrackId') playbackTrackId: string = '';
  @StorageLink('playbackPhase') playbackPhase: PlaybackPhase = 'idle';
  /** 封面落盘后 bump，触发页面重建以切换本地 file URI */
  @StorageLink('coverCacheRevision') coverCacheRevision: number = 0;
  @State private albumId: string = '';
  @State private _playAllLoading: boolean = false;

  private showToast(message: string): void {
    ToastUtil.show(this, message, 1600);
  }

  @Builder
  buildAlbumCoverMenu() {
    MoreMenuIconButton({
      useDarkOverlay: true,
      menuItems: [
        {
          value: '播放全部',
          action: (): void => {
            void this.playAllAlbum();
          }
        },
        {
          value: '添加到播放列表',
          action: (): void => {
            void this.appendAlbumToPlaylist();
          }
        }
      ]
    })
      .margin(6)
  }

  private async appendAlbumToPlaylist(): Promise<void> {
    if (this.vm.album === null) {
      return;
    }
    try {
      const added: number = await PlaybackService.appendAlbumToPlaylist(this.vm.album.id);
      const title: string = this.vm.album.title ?? this.vm.album.name ?? '专辑';
      if (added > 0) {
        this.showToast(`已添加 ${added} 首到播放列表：${title}`);
      } else {
        this.showToast(`曲目已在播放列表中：${title}`);
      }
    } catch (err) {
      const message: string = (err as Error).message;
      this.showToast(message.length > 0 ? message : '添加失败');
    }
  }

  private async playAllAlbum(): Promise<void> {
    if (this.vm.album === null || this._playAllLoading) {
      return;
    }
    this._playAllLoading = true;
    try {
      const coverArt: string = this.vm.album.coverArt ?? '';
      await PlaybackService.playQueue(this.vm.songs, 0, coverArt);
      PlaybackService.setPlaybackMode('listLoop');
    } catch (err) {
      const message: string = (err as Error).message;
      if (message === 'EMPTY_ALBUM') {
        this.showToast('暂无曲目');
      } else {
        this.showToast(message.length > 0 ? message : '加载专辑失败');
      }
    } finally {
      this._playAllLoading = false;
    }
  }

  async aboutToAppear(): Promise<void> {
    const currentIndex: number = this.appPathStack.size() - 1;
    const rawParam: Object | undefined =
      currentIndex >= 0 ? this.appPathStack.getParamByIndex(currentIndex) as Object : undefined;
    const routeParam: AlbumDetailRouteParam | undefined =
      rawParam as AlbumDetailRouteParam | undefined;
    if (routeParam === undefined || routeParam.albumId === undefined || routeParam.albumId.length === 0) {
      this.vm.errorMessage = '缺少专辑参数，无法加载详情';
      return;
    }
    this.albumId = routeParam.albumId;
    await this.vm.load(this.albumId);
  }

  @LocalBuilder
  buildAlbumHeader() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.vm.album !== null && this.vm.album.coverArt !== undefined && this.vm.album.coverArt.length > 0) {
          Image(this.vm.coverUrl(this.vm.album.coverArt))
            .width(180)
            .height(180)
            .borderRadius(18)
            .objectFit(ImageFit.Cover)
            .alt('#E5E5EA')
            .onVisibleAreaChange([0.0, 1.0], (visible: boolean, ratio: number) => {
              if (visible && ratio >= 1.0 && this.vm.album !== null) {
                CoverDisplayResolver.enqueueWhenVisible(this.vm.album.coverArt);
              }
            })
        } else {
          Column() {
            Text('♪')
              .fontSize(56)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          }
          .width(180)
          .height(180)
          .borderRadius(18)
          .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
        this.buildAlbumCoverMenu()
      }
      .width(180)
      .height(180)

      if (this.vm.album !== null) {
        Text(this.vm.album.title ?? this.vm.album.name ?? '未知专辑')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          .margin({ top: 14 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.vm.album.artist} · ${this.vm.songs.length} 首`)
          .fontSize(13)
          .fontColor(UiTokens.COLOR_MUSIC_ARTIST)
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 14 })
    .alignItems(HorizontalAlign.Center)
  }

  @LocalBuilder
  buildSongList() {
    MusicListView({
      songs: this.vm.songs,
      highlightSongId: this.playbackTrackId,
      playingTrackId: this.playbackTrackId,
      playbackPhase: this.playbackPhase,
      listVariant: 'album',
      showArtist: false,
      albumCoverArtId: this.vm.album?.coverArt ?? ''
    })
      .padding({ bottom: 16 })
  }

  @LocalBuilder
  buildPageContent() {
    if (this.vm.isLoading) {
      LoadingState({ message: '正在加载专辑详情…' })
    } else if (this.vm.errorMessage.length > 0 || this.vm.album === null) {
      ErrorState({
        message: this.vm.errorMessage.length > 0 ? this.vm.errorMessage : '专辑详情加载失败',
        onRetryPress: () => {
          void this.vm.load(this.albumId);
        }
      })
    } else {
      this.buildAlbumHeader()
      this.buildSongList()
    }
  }

  @LocalBuilder
  buildDestinationContent() {
    this.buildPageContent()
  }

  build() {
    SecondaryHdsDestination({
      title: '专辑',
      contentVariant: 'hero',
      content: this.buildDestinationContent
    })
  }
}
