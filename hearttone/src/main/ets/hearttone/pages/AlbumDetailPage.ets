import { AlbumDetailRouteParam, Song } from '../api/SubsonicTypes';
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
import { SongCache } from '../cache/SongCache';
import { PlaylistTransferRouteParam } from './PlaylistTransferPage';

type AlbumSongSortMode = 'original' | 'title' | 'artist' | 'duration';

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
  @State private sortMode: AlbumSongSortMode = 'original';
  @State private selectionMode: boolean = false;
  @State private selectedSongIds: string[] = [];
  @State private batchBusy: boolean = false;

  private showToast(message: string): void {
    ToastUtil.show(this, message, 1600);
  }

  private visibleSongs(): Song[] {
    const songs: Song[] = this.vm.songs.slice();
    if (this.sortMode === 'original') {
      return songs;
    }
    songs.sort((left: Song, right: Song): number => {
      if (this.sortMode === 'title') {
        return left.title.localeCompare(right.title);
      }
      if (this.sortMode === 'artist') {
        return left.artist.localeCompare(right.artist);
      }
      return left.duration - right.duration;
    });
    return songs;
  }

  private sortLabel(): string {
    if (this.sortMode === 'title') {
      return '歌名';
    }
    if (this.sortMode === 'artist') {
      return '歌手';
    }
    if (this.sortMode === 'duration') {
      return '时长';
    }
    return '专辑曲序';
  }

  private async chooseSort(): Promise<void> {
    const result = await this.getUIContext().getPromptAction().showActionMenu({
      title: '歌曲排序',
      buttons: [
        { text: '专辑曲序', color: '#1C1C1E' },
        { text: '歌名', color: '#1C1C1E' },
        { text: '歌手', color: '#1C1C1E' },
        { text: '时长', color: '#1C1C1E' }
      ]
    });
    const modes: AlbumSongSortMode[] = ['original', 'title', 'artist', 'duration'];
    if (result.index >= 0 && result.index < modes.length) {
      this.sortMode = modes[result.index];
    }
  }

  private isSongSelected(songId: string): boolean {
    return this.selectedSongIds.indexOf(songId) >= 0;
  }

  private enterSongSelection(song: Song): void {
    this.selectionMode = true;
    if (!this.isSongSelected(song.id)) {
      this.selectedSongIds = this.selectedSongIds.concat([song.id]);
    }
  }

  private toggleSongSelection(song: Song): void {
    if (this.isSongSelected(song.id)) {
      this.selectedSongIds = this.selectedSongIds.filter((id: string) => id !== song.id);
    } else {
      this.selectedSongIds = this.selectedSongIds.concat([song.id]);
    }
  }

  private toggleSelectAllSongs(): void {
    const visible: Song[] = this.visibleSongs();
    let allSelected: boolean = visible.length > 0;
    for (let i: number = 0; i < visible.length; i++) {
      if (!this.isSongSelected(visible[i].id)) {
        allSelected = false;
        break;
      }
    }
    this.selectedSongIds = allSelected ? [] : visible.map((song: Song): string => song.id);
  }

  private exitSongSelection(): void {
    this.selectionMode = false;
    this.selectedSongIds = [];
  }

  private selectedSongs(): Song[] {
    const ids: Set<string> = new Set<string>(this.selectedSongIds);
    return this.visibleSongs().filter((song: Song) => ids.has(song.id));
  }

  private async appendSelectedToPlayback(): Promise<void> {
    const selected: Song[] = this.selectedSongs();
    if (selected.length === 0 || this.batchBusy) {
      return;
    }
    this.batchBusy = true;
    try {
      const added: number = await PlaybackService.appendToPlaylist(selected);
      this.showToast(added > 0 ? `已添加 ${added} 首到播放列表` : '所选歌曲已在播放列表中');
    } finally {
      this.batchBusy = false;
    }
  }

  private openSelectedPlaylistTransfer(): void {
    const selected: Song[] = this.selectedSongs();
    if (selected.length === 0 || this.vm.album === null) {
      return;
    }
    const param: PlaylistTransferRouteParam = {
      sourcePlaylistId: `album-${this.albumId}`,
      sourcePlaylistName: this.vm.album.title ?? this.vm.album.name ?? '专辑',
      sourceSystemFavorite: true,
      songs: selected,
      move: false
    };
    this.appPathStack.pushPathByName('PlaylistTransferPage', param);
  }

  private async downloadSelectedSongs(): Promise<void> {
    const selected: Song[] = this.selectedSongs();
    if (selected.length === 0 || this.batchBusy) {
      return;
    }
    this.batchBusy = true;
    try {
      for (let i: number = 0; i < selected.length; i++) {
        if (!SongCache.isComplete(selected[i].id)) {
          await SongCache.enqueueDownload(selected[i].id);
        }
      }
      this.showToast(`已处理 ${selected.length} 首下载`);
    } finally {
      this.batchBusy = false;
    }
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
      await PlaybackService.playQueue(this.visibleSongs(), 0, coverArt);
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

  @Builder
  private buildSongTools() {
    Row({ space: 8 }) {
      Button(this.sortLabel())
        .layoutWeight(1)
        .height(38)
        .fontSize(12)
        .fontColor(UiTokens.COLOR_PRIMARY)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(8)
        .onClick(() => {
          void this.chooseSort();
        })
      Button('多选')
        .layoutWeight(1)
        .height(38)
        .fontSize(12)
        .fontColor(UiTokens.COLOR_PRIMARY)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(8)
        .onClick(() => {
          this.selectionMode = true;
        })
    }
    .width('100%')
  }

  @Builder
  private buildSelectionToolbar() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Button('取消')
          .height(34)
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
          .borderRadius(8)
          .onClick(() => {
            this.exitSongSelection();
          })
        Text(`已选 ${this.selectedSongIds.length} 首`)
          .layoutWeight(1)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Button('全选')
          .height(34)
          .fontSize(12)
          .fontColor(UiTokens.COLOR_PRIMARY)
          .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
          .borderRadius(8)
          .onClick(() => {
            this.toggleSelectAllSongs();
          })
      }
      .width('100%')

      Row({ space: 7 }) {
        Button('播放列表')
          .layoutWeight(1)
          .height(38)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_PRIMARY)
          .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
          .borderRadius(8)
          .enabled(this.selectedSongIds.length > 0 && !this.batchBusy)
          .onClick(() => {
            void this.appendSelectedToPlayback();
          })
        Button('复制到歌单')
          .layoutWeight(1)
          .height(38)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_PRIMARY)
          .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
          .borderRadius(8)
          .enabled(this.selectedSongIds.length > 0 && !this.batchBusy)
          .onClick(() => {
            this.openSelectedPlaylistTransfer();
          })
        Button('下载')
          .layoutWeight(1)
          .height(38)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_PRIMARY)
          .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
          .borderRadius(8)
          .enabled(this.selectedSongIds.length > 0 && !this.batchBusy)
          .onClick(() => {
            void this.downloadSelectedSongs();
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  @LocalBuilder
  buildSongList() {
    MusicListView({
      songs: this.visibleSongs(),
      highlightSongId: this.playbackTrackId,
      playingTrackId: this.playbackTrackId,
      playbackPhase: this.playbackPhase,
      listVariant: 'album',
      showArtist: false,
      albumCoverArtId: this.vm.album?.coverArt ?? '',
      enableLongPressSelection: true,
      selectionMode: this.selectionMode,
      selectedSongIds: this.selectedSongIds,
      onLongPressSelection: (song: Song): void => {
        this.enterSongSelection(song);
      },
      onSelectionToggle: (song: Song): void => {
        this.toggleSongSelection(song);
      }
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
      if (this.selectionMode) {
        this.buildSelectionToolbar()
      } else {
        this.buildSongTools()
      }
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
