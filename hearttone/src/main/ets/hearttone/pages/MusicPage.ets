import { MusicListKind, Song } from '../api/SubsonicTypes';
import { SuccessButton } from '../components/buttons/SuccessButton';
import {
  MUSIC_KIND_INDEX_RANDOM,
  MusicKindSegment,
  musicKindFromIndex,
  musicKindToIndex
} from '../components/forms/MusicKindSegment';
import { LoadingState } from '../components/feedback/LoadingState';
import { EmptyState } from '../components/feedback/EmptyState';
import { ErrorState } from '../components/feedback/ErrorState';
import { MusicSongRow } from '../components/lists/MusicSongRow';
import { MusicListDataSource } from '../components/lists/MusicListDataSource';
import { ImmersivePageOffsets } from '../ui/layout/ImmersivePageOffsets';
import { TabScrollerBridge } from '../ui/layout/TabScrollerBridge';
import { HeartTonePageRole } from '../ui/layout/HeartTonePageLayoutOptions';
import { UiTokens } from '../ui/tokens/UiTokens';
import { MusicViewModel } from '../viewmodel/MusicViewModel';
import { GlobalPageBackground } from '../components/layout/GlobalPageBackground';
import { PlaybackPhase } from '../playback/PlaybackSnapshot';
import { CardContainer } from '../components/layout/CardContainer';
import { PlaybackService } from '../playback/PlaybackService';
import { UserPlaylist, UserPlaylistStore } from '../settings/UserPlaylistStore';
import { MusicCatalogRepository } from '../domain/music/MusicCatalogRepository';
import { PlaylistDetailRouteParam } from './PlaylistDetailPage';
import { PlaylistArtwork, PlaylistArtworkStore } from '../settings/PlaylistArtworkStore';
import { CoverDisplayResolver } from '../cache/CoverDisplayResolver';
import { SongCache } from '../cache/SongCache';
import { PlaylistTransferRouteParam } from './PlaylistTransferPage';

const MUSIC_KIND_COUNT: number = 5;
const SWIPE_SPEED_THRESHOLD: number = 560;
type SongSortMode = 'original' | 'title' | 'artist' | 'album' | 'duration';

@Component
export struct MusicPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Consume('tabScrollerBridge') tabScrollerBridge: TabScrollerBridge = new TabScrollerBridge();
  @StorageLink('authPhase') @Watch('onAuthSnapshotChanged') authPhase: string = 'booting';
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('rootTabActive') rootTabActive: boolean = false;
  @StorageLink('playbackTrackId') playbackTrackId: string = '';
  @StorageLink('playbackPhase') playbackPhase: PlaybackPhase = 'idle';
  @StorageLink('favoriteRevision') @Watch('onFavoriteRevision') favoriteRevision: number = 0;
  @StorageLink('userPlaylistRevision') @Watch('onPlaylistRevision') userPlaylistRevision: number = 0;
  @StorageLink('playlistArtworkRevision') playlistArtworkRevision: number = 0;
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @State vm: MusicViewModel = MusicViewModel.getInstance();
  @State private refreshSpinDeg: number = 0;
  @State private randomRefreshing: boolean = false;
  @State private userPlaylists: UserPlaylist[] = [];
  @State private favoritePlaylistSongs: Song[] = [];
  @State private favoritePlaylistLoading: boolean = true;
  @State private playingPlaylistId: string = '';
  @State private displaySongs: Song[] = [];
  @State private songSortMode: SongSortMode = 'original';
  @State private songSelectionMode: boolean = false;
  @State private selectedSongIds: string[] = [];
  @State private batchBusy: boolean = false;
  private songDataSource: MusicListDataSource = new MusicListDataSource();
  private favoriteRefreshInFlight: boolean = false;

  aboutToAppear(): void {
    this.onAuthSnapshotChanged();
  }

  private syncSongDataSource(): void {
    this.displaySongs = this.sortedSongs(this.vm.songs);
    this.songDataSource.setSongs(this.displaySongs);
    this.pruneSongSelection();
  }

  private sortedSongs(source: Song[]): Song[] {
    const songs: Song[] = source.slice();
    if (this.songSortMode === 'original') {
      return songs;
    }
    songs.sort((left: Song, right: Song): number => {
      if (this.songSortMode === 'title') {
        return left.title.localeCompare(right.title);
      }
      if (this.songSortMode === 'artist') {
        return left.artist.localeCompare(right.artist);
      }
      if (this.songSortMode === 'album') {
        return left.album.localeCompare(right.album);
      }
      return left.duration - right.duration;
    });
    return songs;
  }

  private onAuthSnapshotChanged(): void {
    if (this.authPhase === 'authenticated' && this.isLoggedIn) {
      void this.activateMusic();
    } else if (this.authPhase === 'anonymous') {
      this.vm.reset();
    }
  }

  private async activateMusic(): Promise<void> {
    await UserPlaylistStore.getInstance().ensureReady();
    this.userPlaylists = UserPlaylistStore.getInstance().list();
    await this.vm.restoreKindFromStore();
    if (this.vm.isSearchMode) {
      this.vm.clearSearchMode();
    }
    if (this.vm.songs.length === 0 || this.vm.kind === 'favorite') {
      await this.vm.loadCurrentKind();
    }
    this.syncSongDataSource();
    if (this.vm.kind === 'favorite') {
      await this.refreshFavoritePlaylist();
    }
  }

  private onFavoriteRevision(): void {
    this.vm.reconcileFavoriteState();
    this.syncSongDataSource();
    void this.refreshFavoritePlaylist();
  }

  private async refreshFavoritePlaylist(): Promise<void> {
    if (this.favoriteRefreshInFlight) {
      return;
    }
    this.favoriteRefreshInFlight = true;
    this.favoritePlaylistLoading = true;
    try {
      this.favoritePlaylistSongs = await MusicCatalogRepository.getInstance().favoriteSongs();
    } catch (_err) {
      this.favoritePlaylistSongs = [];
    } finally {
      this.favoriteRefreshInFlight = false;
      this.favoritePlaylistLoading = false;
    }
  }

  private openPlaylistDetail(id: string, name: string, systemFavorite: boolean): void {
    const param: PlaylistDetailRouteParam = {
      playlistId: id,
      playlistName: name,
      systemFavorite: systemFavorite
    };
    this.appPathStack.pushPathByName('PlaylistDetailPage', param);
  }

  private playlistArtworkUri(id: string): string {
    const artwork: PlaylistArtwork = PlaylistArtworkStore.getInstance().artworkFor(id);
    if (artwork.imageUri.length > 0) {
      return artwork.imageUri;
    }
    return artwork.coverArtId.length > 0 ? CoverDisplayResolver.resolve(artwork.coverArtId, 160) ?? '' : '';
  }

  private onPlaylistRevision(): void {
    this.userPlaylists = UserPlaylistStore.getInstance().list();
  }

  private playlistSummary(songs: Song[]): string {
    if (songs.length === 0) {
      return '暂无歌曲';
    }
    const names: string[] = [];
    const count: number = Math.min(2, songs.length);
    for (let i: number = 0; i < count; i++) {
      names.push(songs[i].title);
    }
    return names.join(' · ');
  }

  private async playPlaylist(id: string, name: string, songs: Song[]): Promise<void> {
    if (songs.length === 0 || this.playingPlaylistId.length > 0) {
      return;
    }
    this.playingPlaylistId = id;
    try {
      await PlaybackService.playQueue(songs, 0);
      this.getUIContext().getPromptAction().showToast({ message: `正在播放「${name}」`, duration: 1600 });
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({
        message: (err as Error).message || '播放失败',
        duration: 1600
      });
    } finally {
      this.playingPlaylistId = '';
    }
  }

  private retryLoad(): void {
    void this.vm.loadCurrentKind().then(() => {
      this.syncSongDataSource();
    });
  }

  private triggerRefreshSpin(): void {
    this.getUIContext()?.animateTo(
      { duration: 400, curve: Curve.EaseOut },
      () => {
        this.refreshSpinDeg = this.refreshSpinDeg + 360;
      }
    );
  }

  private async handleKindSelect(index: number): Promise<void> {
    this.exitSongSelection();
    const nextKind: MusicListKind = musicKindFromIndex(index);
    if (index === MUSIC_KIND_INDEX_RANDOM &&
      musicKindToIndex(this.vm.kind) === MUSIC_KIND_INDEX_RANDOM) {
      if (this.randomRefreshing || this.vm.isLoading) {
        return;
      }
      this.randomRefreshing = true;
      this.triggerRefreshSpin();
      await this.vm.reloadRandom();
      this.syncSongDataSource();
      this.randomRefreshing = false;
      return;
    }
    await this.vm.setKind(nextKind);
    this.syncSongDataSource();
    if (nextKind === 'favorite') {
      await this.refreshFavoritePlaylist();
    }
  }

  private async handleHorizontalSwipe(event: GestureEvent): Promise<void> {
    if (this.songSelectionMode || this.vm.isLoading || this.randomRefreshing || event.speed < SWIPE_SPEED_THRESHOLD) {
      return;
    }
    const currentIndex: number = musicKindToIndex(this.vm.kind);
    const movingRight: boolean = Math.cos(event.angle * Math.PI / 180) > 0;
    const delta: number = movingRight ? -1 : 1;
    const nextIndex: number = (currentIndex + delta + MUSIC_KIND_COUNT) % MUSIC_KIND_COUNT;
    await this.handleKindSelect(nextIndex);
  }

  private sortLabel(): string {
    if (this.songSortMode === 'title') {
      return '歌名';
    }
    if (this.songSortMode === 'artist') {
      return '歌手';
    }
    if (this.songSortMode === 'album') {
      return '专辑';
    }
    if (this.songSortMode === 'duration') {
      return '时长';
    }
    return '默认排序';
  }

  private async chooseSongSort(): Promise<void> {
    const result = await this.getUIContext().getPromptAction().showActionMenu({
      title: '歌曲排序',
      buttons: [
        { text: '默认排序', color: '#1C1C1E' },
        { text: '歌名', color: '#1C1C1E' },
        { text: '歌手', color: '#1C1C1E' },
        { text: '专辑', color: '#1C1C1E' },
        { text: '时长', color: '#1C1C1E' }
      ]
    });
    const modes: SongSortMode[] = ['original', 'title', 'artist', 'album', 'duration'];
    if (result.index >= 0 && result.index < modes.length) {
      this.songSortMode = modes[result.index];
      this.syncSongDataSource();
    }
  }

  private isSongSelected(songId: string): boolean {
    return this.selectedSongIds.indexOf(songId) >= 0;
  }

  private enterSongSelection(song: Song): void {
    this.songSelectionMode = true;
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
    let allSelected: boolean = this.displaySongs.length > 0;
    for (let i: number = 0; i < this.displaySongs.length; i++) {
      if (!this.isSongSelected(this.displaySongs[i].id)) {
        allSelected = false;
        break;
      }
    }
    this.selectedSongIds = allSelected ? [] : this.displaySongs.map((song: Song): string => song.id);
  }

  private exitSongSelection(): void {
    this.songSelectionMode = false;
    this.selectedSongIds = [];
  }

  private pruneSongSelection(): void {
    const availableIds: Set<string> = new Set<string>(this.vm.songs.map((song: Song): string => song.id));
    this.selectedSongIds = this.selectedSongIds.filter((id: string) => availableIds.has(id));
  }

  private selectedSongs(): Song[] {
    const ids: Set<string> = new Set<string>(this.selectedSongIds);
    return this.displaySongs.filter((song: Song) => ids.has(song.id));
  }

  private async appendSelectedToPlayback(): Promise<void> {
    const selected: Song[] = this.selectedSongs();
    if (selected.length === 0 || this.batchBusy) {
      return;
    }
    this.batchBusy = true;
    try {
      const added: number = await PlaybackService.appendToPlaylist(selected);
      this.getUIContext().getPromptAction().showToast({
        message: added > 0 ? `已添加 ${added} 首到播放列表` : '所选歌曲已在播放列表中',
        duration: 1600
      });
    } finally {
      this.batchBusy = false;
    }
  }

  private openSelectedPlaylistTransfer(): void {
    const selected: Song[] = this.selectedSongs();
    if (selected.length === 0) {
      return;
    }
    const param: PlaylistTransferRouteParam = {
      sourcePlaylistId: `music-${this.vm.kind}`,
      sourcePlaylistName: '音乐',
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
      this.getUIContext().getPromptAction().showToast({ message: `已处理 ${selected.length} 首下载`, duration: 1600 });
    } finally {
      this.batchBusy = false;
    }
  }

  private async removeSelectedFromRecent(): Promise<void> {
    if (this.vm.kind !== 'recent' || this.selectedSongIds.length === 0 || this.batchBusy) {
      return;
    }
    this.batchBusy = true;
    try {
      const ids: string[] = this.selectedSongIds.slice();
      for (let i: number = 0; i < ids.length; i++) {
        await this.vm.removeFromRecent(ids[i]);
      }
      this.exitSongSelection();
      this.syncSongDataSource();
      this.getUIContext().getPromptAction().showToast({ message: `已移除 ${ids.length} 首最近播放`, duration: 1600 });
    } finally {
      this.batchBusy = false;
    }
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
          void this.chooseSongSort();
        })
      Button('多选')
        .layoutWeight(1)
        .height(38)
        .fontSize(12)
        .fontColor(UiTokens.COLOR_PRIMARY)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(8)
        .onClick(() => {
          this.songSelectionMode = true;
        })
    }
    .width('100%')
    .margin({ top: 10 })
  }

  @Builder
  private buildSongSelectionToolbar() {
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

      if (this.vm.kind === 'recent') {
        Button('从最近播放移除')
          .width('100%')
          .height(38)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_DANGER)
          .backgroundColor(UiTokens.COLOR_DANGER_SOFT_BG)
          .borderRadius(8)
          .enabled(this.selectedSongIds.length > 0 && !this.batchBusy)
          .onClick(() => {
            void this.removeSelectedFromRecent();
          })
      }
    }
    .width('100%')
    .margin({ top: 10 })
  }

  @Builder
  private buildMusicListHeader() {
    Column() {
      MusicKindSegment({
        selectedIndex: musicKindToIndex(this.vm.kind),
        refreshSpinDeg: this.refreshSpinDeg,
        onSelect: (index: number) => {
          void this.handleKindSelect(index);
        }
      })
      if (this.vm.kind !== 'favorite' && this.vm.songs.length > 0) {
        if (this.songSelectionMode) {
          this.buildSongSelectionToolbar()
        } else {
          this.buildSongTools()
        }
      }
    }
    .width('100%')
    .padding({
      top: ImmersivePageOffsets.contentTopPadding(HeartTonePageRole.TAB_ROOT, this.topInset),
      left: UiTokens.PAGE_HORIZONTAL_PADDING,
      right: UiTokens.PAGE_HORIZONTAL_PADDING
    })
    .margin({ bottom: UiTokens.SECTION_GAP })
  }

  @Builder
  private buildSongsList() {
    List({ scroller: this.tabScrollerBridge.scrollerForTab(0) }) {
      ListItemGroup({ header: this.buildMusicListHeader }) {
        if (this.vm.kind === 'favorite') {
          if (this.favoritePlaylistLoading) {
            ListItem() {
              LoadingState({ message: '正在加载歌单…' })
            }
          } else {
            ListItem() {
              this.playlistRow('favorite', '喜爱', this.favoritePlaylistSongs, true)
            }
            ForEach(this.userPlaylists, (playlist: UserPlaylist) => {
              ListItem() {
                this.playlistRow(playlist.id, playlist.name, playlist.songs, false)
              }
            }, (playlist: UserPlaylist) => playlist.id)
          }
        } else if (this.vm.isLoading && this.vm.songs.length === 0) {
          ListItem() {
            LoadingState({ message: '正在加载歌曲…' })
          }
        } else if (this.vm.errorMessage.length > 0 && this.vm.songs.length === 0) {
          ListItem() {
            Column() {
              ErrorState({
                message: this.vm.errorMessage,
                onRetryPress: () => {
                  this.retryLoad();
                }
              })
              if (this.vm.authExpired) {
                SuccessButton({
                  text: '重新登录',
                  onPressed: () => {
                    this.appPathStack.replacePathByName('LoginPage', null);
                  }
                })
                  .margin({ top: 10 })
              }
            }
            .width('100%')
            .padding({ left: 6, right: 6 })
          }
        } else if (this.vm.songs.length === 0) {
          ListItem() {
            EmptyState({
              icon: '',
              title: '暂无歌曲',
              subtitle: this.isLoggedIn ? '还没有可展示的曲目' : '请在我的 > 服务器完成登录',
              contentPaddingTop: 56
            })
          }
        } else {
          LazyForEach(this.songDataSource, (song: Song, index: number) => {
            ListItem() {
              MusicSongRow({
                song: song,
                index: index,
                songs: this.displaySongs,
                highlightSongId: this.playbackTrackId,
                playingTrackId: this.playbackTrackId,
                playbackPhase: this.playbackPhase,
                showArtist: true,
                showAlbumCover: true,
                showRemoveFromRecent: this.vm.kind === 'recent',
                enableLongPressSelection: true,
                selectionMode: this.songSelectionMode,
                selected: this.isSongSelected(song.id),
                onLongPressSelection: (selectedSong: Song): void => {
                  this.enterSongSelection(selectedSong);
                },
                onSelectionToggle: (selectedSong: Song): void => {
                  this.toggleSongSelection(selectedSong);
                }
              })
            }
          }, (song: Song) => song.id)
        }

        if (this.vm.isLoadingMore) {
          ListItem() {
            Row() {
              LoadingProgress()
                .width(22)
                .height(22)
                .color(UiTokens.COLOR_TEXT_SECONDARY)
              Text('加载中…')
                .fontSize(13)
                .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                .margin({ left: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 8, bottom: 8 })
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: UiTokens.PAGE_HORIZONTAL_PADDING,
      right: UiTokens.PAGE_HORIZONTAL_PADDING
    })
    .backgroundColor(Color.Transparent)
    .contentEndOffset(ImmersivePageOffsets.tabContentEnd(this.bottomInset, this.rootTabActive))
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onReachEnd(() => {
      if (this.vm.kind !== 'favorite') {
        void this.vm.loadMore().then(() => {
          this.syncSongDataSource();
        });
      }
    })
    .parallelGesture(
      SwipeGesture({ direction: SwipeDirection.Horizontal, speed: SWIPE_SPEED_THRESHOLD })
        .onAction((event: GestureEvent) => {
          void this.handleHorizontalSwipe(event);
        })
    )
  }

  @Builder
  private playlistRow(id: string, name: string, songs: Song[], systemPlaylist: boolean) {
    CardContainer() {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.playlistArtworkUri(id).length > 0) {
            Image(this.playlistArtworkUri(id))
              .width(48)
              .height(48)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
          } else {
            Column()
              .width(48)
              .height(48)
              .borderRadius(12)
              .backgroundColor(systemPlaylist ? UiTokens.COLOR_DANGER_SOFT_BG : UiTokens.COLOR_PRIMARY_SOFT_BG)
            Image(systemPlaylist ? $r('app.media.ic_heart_filled') : $r('app.media.ic_playlist_library'))
              .width(22)
              .height(22)
              .fillColor(systemPlaylist ? UiTokens.COLOR_DANGER : UiTokens.COLOR_PRIMARY)
          }
        }
        .width(48)
        .height(48)
        .onClick(() => {
          this.openPlaylistDetail(id, name, systemPlaylist);
        })

        Column({ space: 4 }) {
          Text(name)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${songs.length} 首 · ${this.playlistSummary(songs)}`)
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          this.openPlaylistDetail(id, name, systemPlaylist);
        })

        if (this.playingPlaylistId === id) {
          LoadingProgress()
            .width(22)
            .height(22)
            .color(UiTokens.COLOR_PRIMARY)
        } else {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.cb_play'))
              .width(16)
              .height(16)
              .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
          }
          .width(36)
          .height(36)
          .backgroundColor(UiTokens.COLOR_PRIMARY)
          .enabled(songs.length > 0 && this.playingPlaylistId.length === 0)
          .onClick(() => {
            void this.playPlaylist(id, name, songs);
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private buildBootingBody() {
    Column() {
      LoadingState({ message: '正在恢复会话…' })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildAnonymousBody() {
    Column() {
      EmptyState({
        title: '未登录',
        subtitle: '请在我的 > 服务器完成登录'
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: UiTokens.PAGE_HORIZONTAL_PADDING, right: UiTokens.PAGE_HORIZONTAL_PADDING })
  }

  build() {
    if (this.authPhase === 'authenticated' && this.isLoggedIn) {
      Stack() {
        GlobalPageBackground()
        Column() {
          this.buildSongsList()
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .id('bar-tone-probe-0')
    } else if (this.authPhase === 'booting') {
      this.buildBootingBody()
    } else {
      this.buildAnonymousBody()
    }
  }
}
