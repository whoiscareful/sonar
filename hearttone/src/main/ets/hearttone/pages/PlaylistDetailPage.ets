import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { Song } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { CoverDisplayResolver } from '../cache/CoverDisplayResolver';
import { LoadingState } from '../components/feedback/LoadingState';
import { MusicListView } from '../components/lists/MusicListView';
import { SecondaryHdsDestination } from '../components/navigation/SecondaryHdsDestination';
import { FavoriteSyncService } from '../domain/music/FavoriteSyncService';
import { MusicCatalogRepository } from '../domain/music/MusicCatalogRepository';
import { PlaybackService } from '../playback/PlaybackService';
import { PlaybackPhase } from '../playback/PlaybackSnapshot';
import { PlaylistArtwork, PlaylistArtworkStore } from '../settings/PlaylistArtworkStore';
import { UserPlaylist, UserPlaylistStore } from '../settings/UserPlaylistStore';
import { UiTokens } from '../ui/tokens/UiTokens';
import { PlaylistTransferRouteParam } from './PlaylistTransferPage';

export interface PlaylistDetailRouteParam {
  playlistId: string;
  playlistName: string;
  systemFavorite: boolean;
}

type SongSortMode = 'original' | 'title' | 'artist' | 'album' | 'duration';

@Component
export struct PlaylistDetailPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink('favoriteRevision') @Watch('onFavoriteRevision') favoriteRevision: number = 0;
  @StorageLink('userPlaylistRevision') @Watch('onPlaylistRevision') userPlaylistRevision: number = 0;
  @StorageLink('playlistArtworkRevision') @Watch('onArtworkRevision') playlistArtworkRevision: number = 0;
  @StorageLink('coverCacheRevision') coverCacheRevision: number = 0;
  @StorageLink('playbackTrackId') playbackTrackId: string = '';
  @StorageLink('playbackPhase') playbackPhase: PlaybackPhase = 'idle';
  @State private playlistId: string = '';
  @State private playlistName: string = '歌单';
  @State private playlistDescription: string = '';
  @State private systemFavorite: boolean = false;
  @State private songs: Song[] = [];
  @State private artwork: PlaylistArtwork = { imageUri: '', coverArtId: '' };
  @State private loading: boolean = true;
  @State private busy: boolean = false;
  @State private searchText: string = '';
  @State private sortMode: SongSortMode = 'original';
  @State private selectionMode: boolean = false;
  @State private selectedSongIds: string[] = [];
  @State private editingDetails: boolean = false;
  @State private draftName: string = '';
  @State private draftDescription: string = '';

  async aboutToAppear(): Promise<void> {
    const currentIndex: number = this.appPathStack.size() - 1;
    const rawParam: Object | undefined = currentIndex >= 0 ?
      this.appPathStack.getParamByIndex(currentIndex) as Object : undefined;
    const param: PlaylistDetailRouteParam | undefined = rawParam as PlaylistDetailRouteParam | undefined;
    if (param === undefined || param.playlistId === undefined || param.playlistId.length === 0) {
      this.loading = false;
      this.showToast('缺少歌单参数');
      return;
    }
    this.playlistId = param.playlistId;
    this.playlistName = param.playlistName.length > 0 ? param.playlistName : '歌单';
    this.systemFavorite = param.systemFavorite;
    await this.loadPlaylist();
  }

  private onFavoriteRevision(): void {
    if (this.systemFavorite) {
      void this.loadSongs();
    }
  }

  private onPlaylistRevision(): void {
    if (!this.systemFavorite) {
      void this.loadSongs();
    }
  }

  private onArtworkRevision(): void {
    this.artwork = PlaylistArtworkStore.getInstance().artworkFor(this.playlistId);
  }

  private async loadPlaylist(): Promise<void> {
    this.loading = true;
    await PlaylistArtworkStore.getInstance().ensureReady();
    this.artwork = PlaylistArtworkStore.getInstance().artworkFor(this.playlistId);
    await this.loadSongs();
    this.loading = false;
  }

  private async loadSongs(): Promise<void> {
    if (this.playlistId.length === 0) {
      return;
    }
    try {
      if (this.systemFavorite) {
        this.songs = await MusicCatalogRepository.getInstance().favoriteSongs();
        this.playlistDescription = '与服务器喜爱实时同步';
      } else {
        await UserPlaylistStore.getInstance().ensureReady();
        const playlist: UserPlaylist | null = UserPlaylistStore.getInstance().get(this.playlistId);
        this.songs = playlist === null ? [] : playlist.songs;
        if (playlist !== null) {
          this.playlistName = playlist.name;
          this.playlistDescription = playlist.description;
        }
      }
      this.pruneSongSelection();
    } catch (err) {
      this.showToast(`歌单加载失败：${(err as Error).message}`);
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
  }

  private visibleSongs(): Song[] {
    const keyword: string = this.searchText.trim().toLowerCase();
    const result: Song[] = [];
    for (let i: number = 0; i < this.songs.length; i++) {
      const song: Song = this.songs[i];
      if (keyword.length === 0 || song.title.toLowerCase().includes(keyword) ||
        song.artist.toLowerCase().includes(keyword) || song.album.toLowerCase().includes(keyword)) {
        result.push(song);
      }
    }
    result.sort((left: Song, right: Song): number => {
      if (this.sortMode === 'title') {
        return left.title.localeCompare(right.title);
      }
      if (this.sortMode === 'artist') {
        return left.artist.localeCompare(right.artist);
      }
      if (this.sortMode === 'album') {
        return left.album.localeCompare(right.album);
      }
      if (this.sortMode === 'duration') {
        return left.duration - right.duration;
      }
      return this.originalIndex(left.id) - this.originalIndex(right.id);
    });
    return result;
  }

  private originalIndex(songId: string): number {
    for (let i: number = 0; i < this.songs.length; i++) {
      if (this.songs[i].id === songId) {
        return i;
      }
    }
    return this.songs.length;
  }

  private sortLabel(): string {
    if (this.sortMode === 'title') {
      return '歌名';
    }
    if (this.sortMode === 'artist') {
      return '歌手';
    }
    if (this.sortMode === 'album') {
      return '专辑';
    }
    if (this.sortMode === 'duration') {
      return '时长';
    }
    return '默认顺序';
  }

  private async chooseSort(): Promise<void> {
    const result = await this.getUIContext().getPromptAction().showActionMenu({
      title: '歌曲排序',
      buttons: [
        { text: '默认顺序', color: '#1C1C1E' },
        { text: '歌名', color: '#1C1C1E' },
        { text: '歌手', color: '#1C1C1E' },
        { text: '专辑', color: '#1C1C1E' },
        { text: '时长', color: '#1C1C1E' }
      ]
    });
    if (result.index === 0) {
      this.sortMode = 'original';
    } else if (result.index === 1) {
      this.sortMode = 'title';
    } else if (result.index === 2) {
      this.sortMode = 'artist';
    } else if (result.index === 3) {
      this.sortMode = 'album';
    } else if (result.index === 4) {
      this.sortMode = 'duration';
    }
  }

  private resolvedCoverUri(): string {
    if (this.artwork.imageUri.length > 0) {
      return this.artwork.imageUri;
    }
    if (this.artwork.coverArtId.length > 0) {
      return CoverDisplayResolver.resolve(this.artwork.coverArtId, 420) ?? '';
    }
    return '';
  }

  private firstAlbumCoverArtId(): string {
    for (let i: number = 0; i < this.songs.length; i++) {
      const coverArt: string = this.songs[i].coverArt ?? '';
      if (coverArt.length > 0) {
        return coverArt;
      }
    }
    return '';
  }

  private async playAll(): Promise<void> {
    const visible: Song[] = this.visibleSongs();
    if (this.busy || visible.length === 0 || this.selectionMode) {
      return;
    }
    this.busy = true;
    try {
      await PlaybackService.playQueue(visible, 0, this.firstAlbumCoverArtId());
      PlaybackService.setPlaybackMode('listLoop');
    } catch (err) {
      this.showToast((err as Error).message || '播放失败');
    } finally {
      this.busy = false;
    }
  }

  private async pickManualCover(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length > 0) {
        await PlaylistArtworkStore.getInstance().setManualImage(this.playlistId, result.photoUris[0]);
        this.artwork = PlaylistArtworkStore.getInstance().artworkFor(this.playlistId);
        this.showToast('歌单封面已更新');
      }
    } catch (err) {
      this.showToast(`封面更新失败：${(err as Error).message}`);
    } finally {
      this.busy = false;
    }
  }

  private async useRandomCover(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      await PlaylistArtworkStore.getInstance().setRandomImage(this.playlistId);
      this.artwork = PlaylistArtworkStore.getInstance().artworkFor(this.playlistId);
      this.showToast('已生成随机封面');
    } catch (err) {
      this.showToast(`随机封面失败：${(err as Error).message}`);
    } finally {
      this.busy = false;
    }
  }

  private async useAlbumCover(): Promise<void> {
    const coverArtId: string = this.firstAlbumCoverArtId();
    if (coverArtId.length === 0) {
      this.showToast('歌单歌曲暂无可用专辑封面');
      return;
    }
    await PlaylistArtworkStore.getInstance().setAlbumCover(this.playlistId, coverArtId);
    this.artwork = PlaylistArtworkStore.getInstance().artworkFor(this.playlistId);
    CoverDisplayResolver.enqueueWhenVisible(coverArtId);
    this.showToast('已使用歌曲专辑封面');
  }

  private async resetCover(): Promise<void> {
    await PlaylistArtworkStore.getInstance().clear(this.playlistId);
    this.artwork = PlaylistArtworkStore.getInstance().artworkFor(this.playlistId);
    this.showToast('已恢复默认封面');
  }

  private beginEditDetails(): void {
    if (this.systemFavorite) {
      return;
    }
    this.draftName = this.playlistName;
    this.draftDescription = this.playlistDescription;
    this.editingDetails = true;
  }

  private async saveDetails(): Promise<void> {
    if (this.busy || this.systemFavorite) {
      return;
    }
    this.busy = true;
    try {
      const updated: boolean = await UserPlaylistStore.getInstance().updateDetails(
        this.playlistId, this.draftName, this.draftDescription);
      if (updated) {
        this.playlistName = this.draftName.trim();
        this.playlistDescription = this.draftDescription.trim();
        this.editingDetails = false;
        this.showToast('歌单信息已更新');
      }
    } catch (err) {
      this.showToast(`保存失败：${(err as Error).message}`);
    } finally {
      this.busy = false;
    }
  }

  private async deduplicatePlaylist(): Promise<void> {
    if (this.busy || this.systemFavorite) {
      return;
    }
    this.busy = true;
    try {
      const removed: number = await UserPlaylistStore.getInstance().deduplicate(this.playlistId);
      this.showToast(removed > 0 ? `已移除 ${removed} 首重复歌曲` : '未发现重复歌曲');
    } finally {
      this.busy = false;
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
    if (allSelected) {
      const visibleIds: Set<string> = new Set<string>();
      for (let i: number = 0; i < visible.length; i++) {
        visibleIds.add(visible[i].id);
      }
      this.selectedSongIds = this.selectedSongIds.filter((id: string) => !visibleIds.has(id));
      return;
    }
    const nextIds: Set<string> = new Set<string>(this.selectedSongIds);
    for (let i: number = 0; i < visible.length; i++) {
      nextIds.add(visible[i].id);
    }
    this.selectedSongIds = Array.from(nextIds);
  }

  private exitSongSelection(): void {
    this.selectionMode = false;
    this.selectedSongIds = [];
  }

  private pruneSongSelection(): void {
    const availableIds: Set<string> = new Set<string>();
    for (let i: number = 0; i < this.songs.length; i++) {
      availableIds.add(this.songs[i].id);
    }
    this.selectedSongIds = this.selectedSongIds.filter((id: string) => availableIds.has(id));
    if (this.selectionMode && this.selectedSongIds.length === 0) {
      this.exitSongSelection();
    }
  }

  private selectedSongs(): Song[] {
    const selectedIds: Set<string> = new Set<string>(this.selectedSongIds);
    return this.songs.filter((song: Song) => selectedIds.has(song.id));
  }

  private openTransfer(move: boolean): void {
    const selected: Song[] = this.selectedSongs();
    if (selected.length === 0 || (move && this.systemFavorite)) {
      return;
    }
    const param: PlaylistTransferRouteParam = {
      sourcePlaylistId: this.playlistId,
      sourcePlaylistName: this.playlistName,
      sourceSystemFavorite: this.systemFavorite,
      songs: selected,
      move: move
    };
    this.appPathStack.pushPathByName('PlaylistTransferPage', param);
  }

  private async removeSelectedSongs(): Promise<void> {
    if (this.selectedSongIds.length === 0 || this.busy) {
      return;
    }
    const actionName: string = this.systemFavorite ? '取消喜爱' : '移出歌单';
    const result = await this.getUIContext().getPromptAction().showDialog({
      title: `${actionName} ${this.selectedSongIds.length} 首歌曲？`,
      message: this.systemFavorite ? '所选歌曲会与服务器取消喜爱状态。' : '歌曲只会从当前歌单移除，不会从曲库删除。',
      buttons: [
        { text: '取消', color: '#7A7F8A' },
        { text: actionName, color: '#D9485F' }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    this.busy = true;
    try {
      const ids: string[] = this.selectedSongIds.slice();
      if (this.systemFavorite) {
        const client: SubsonicClient = SubsonicClient.getInstance();
        for (let i: number = 0; i < ids.length; i++) {
          await client.setSongStarred(ids[i], false);
        }
        await FavoriteSyncService.getInstance().refreshAll();
      } else {
        await UserPlaylistStore.getInstance().removeSongs(this.playlistId, ids);
      }
      this.exitSongSelection();
      await this.loadSongs();
      this.showToast(`已处理 ${ids.length} 首歌曲`);
    } catch (err) {
      this.showToast(`批量操作失败：${(err as Error).message}`);
    } finally {
      this.busy = false;
    }
  }

  @Builder
  private coverButton(title: string, action: () => void) {
    Button(title)
      .layoutWeight(1)
      .height(36)
      .fontSize(11)
      .fontColor(UiTokens.COLOR_PRIMARY)
      .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
      .borderRadius(8)
      .enabled(!this.busy)
      .onClick(() => {
        action();
      })
  }

  @Builder
  private editDetailsPanel() {
    Column({ space: 8 }) {
      TextInput({ text: this.draftName, placeholder: '歌单名称' })
        .width('100%')
        .height(40)
        .fontSize(13)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(8)
        .onChange((value: string) => {
          this.draftName = value;
        })
      TextArea({ text: this.draftDescription, placeholder: '添加歌单描述' })
        .width('100%')
        .height(76)
        .fontSize(12)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(8)
        .onChange((value: string) => {
          this.draftDescription = value;
        })
      Row({ space: 8 }) {
        Button('取消')
          .layoutWeight(1)
          .height(36)
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
          .borderRadius(8)
          .onClick(() => {
            this.editingDetails = false;
          })
        Button('保存')
          .layoutWeight(1)
          .height(36)
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
          .backgroundColor(UiTokens.COLOR_PRIMARY)
          .borderRadius(8)
          .enabled(this.draftName.trim().length > 0 && !this.busy)
          .onClick(() => {
            void this.saveDetails();
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  @LocalBuilder
  private buildHeader() {
    Column({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.resolvedCoverUri().length > 0) {
          Image(this.resolvedCoverUri())
            .width(152)
            .height(152)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
            .onVisibleAreaChange([0.0, 1.0], (visible: boolean, ratio: number) => {
              if (visible && ratio >= 1.0 && this.artwork.coverArtId.length > 0) {
                CoverDisplayResolver.enqueueWhenVisible(this.artwork.coverArtId);
              }
            })
        } else {
          Column() {
            Image(this.systemFavorite ? $r('app.media.ic_heart_filled') : $r('app.media.ic_playlist_library'))
              .width(46)
              .height(46)
              .fillColor(this.systemFavorite ? UiTokens.COLOR_DANGER : UiTokens.COLOR_PRIMARY)
          }
          .width(152)
          .height(152)
          .borderRadius(16)
          .backgroundColor(this.systemFavorite ? UiTokens.COLOR_DANGER_SOFT_BG : UiTokens.COLOR_PRIMARY_SOFT_BG)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width(152)
      .height(152)

      Text(this.playlistName)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.playlistDescription.length > 0) {
        Text(this.playlistDescription)
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Text(`${this.songs.length} 首${this.systemFavorite ? ' · 服务器歌单' : ''}`)
        .fontSize(11)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)

      Row({ space: 8 }) {
        Button(this.busy ? '处理中' : '播放全部')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
          .backgroundColor(UiTokens.COLOR_PRIMARY)
          .borderRadius(9)
          .enabled(!this.busy && this.visibleSongs().length > 0)
          .onClick(() => {
            void this.playAll();
          })
        if (!this.systemFavorite) {
          Button('编辑信息')
            .layoutWeight(1)
            .height(40)
            .fontSize(12)
            .fontColor(UiTokens.COLOR_PRIMARY)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .borderRadius(9)
            .onClick(() => {
              this.beginEditDetails();
            })
          Button('去重')
            .layoutWeight(1)
            .height(40)
            .fontSize(12)
            .fontColor(UiTokens.COLOR_PRIMARY)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .borderRadius(9)
            .enabled(!this.busy && this.songs.length > 1)
            .onClick(() => {
              void this.deduplicatePlaylist();
            })
        }
      }
      .width('100%')

      if (this.editingDetails) {
        this.editDetailsPanel()
      }

      Row({ space: 6 }) {
        this.coverButton('本地图片', () => { void this.pickManualCover(); })
        this.coverButton('随机图片', () => { void this.useRandomCover(); })
        this.coverButton('专辑封面', () => { void this.useAlbumCover(); })
        this.coverButton('恢复默认', () => { void this.resetCover(); })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 4, bottom: 10 })
  }

  @Builder
  private searchAndSort() {
    Row({ space: 8 }) {
      TextInput({ text: this.searchText, placeholder: '搜索歌曲、歌手或专辑' })
        .layoutWeight(1)
        .height(40)
        .fontSize(13)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(9)
        .onChange((value: string) => {
          this.searchText = value;
        })
      Button(this.sortLabel())
        .height(40)
        .padding({ left: 11, right: 11 })
        .fontSize(11)
        .fontColor(UiTokens.COLOR_PRIMARY)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(9)
        .onClick(() => {
          void this.chooseSort();
        })
      Button('多选')
        .height(40)
        .padding({ left: 11, right: 11 })
        .fontSize(11)
        .fontColor(UiTokens.COLOR_PRIMARY)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(9)
        .enabled(this.songs.length > 0)
        .onClick(() => {
          this.selectionMode = true;
        })
    }
    .width('100%')
  }

  @Builder
  private selectionToolbar() {
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
        Button('复制到歌单')
          .layoutWeight(1)
          .height(38)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_PRIMARY)
          .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
          .borderRadius(8)
          .enabled(this.selectedSongIds.length > 0 && !this.busy)
          .onClick(() => {
            this.openTransfer(false);
          })
        if (!this.systemFavorite) {
          Button('移动到歌单')
            .layoutWeight(1)
            .height(38)
            .fontSize(11)
            .fontColor(UiTokens.COLOR_PRIMARY)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .borderRadius(8)
            .enabled(this.selectedSongIds.length > 0 && !this.busy)
            .onClick(() => {
              this.openTransfer(true);
            })
        }
        Button(this.systemFavorite ? '取消喜爱' : '移出歌单')
          .layoutWeight(1)
          .height(38)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_DANGER)
          .backgroundColor(UiTokens.COLOR_DANGER_SOFT_BG)
          .borderRadius(8)
          .enabled(this.selectedSongIds.length > 0 && !this.busy)
          .onClick(() => {
            void this.removeSelectedSongs();
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  @LocalBuilder
  private buildContent() {
    if (this.loading) {
      LoadingState({ message: '正在加载歌单…' })
    } else {
      this.buildHeader()
      this.searchAndSort()
      if (this.selectionMode) {
        this.selectionToolbar()
      }
      if (this.visibleSongs().length === 0) {
        Text(this.searchText.trim().length > 0 ? '没有匹配的歌曲' : '暂无歌曲')
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontSize(14)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          .padding({ top: 32, bottom: 32 })
      } else {
        MusicListView({
          songs: this.visibleSongs(),
          highlightSongId: this.playbackTrackId,
          playingTrackId: this.playbackTrackId,
          playbackPhase: this.playbackPhase,
          listVariant: 'browse',
          showArtist: true,
          showAlbumCover: true,
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
    }
  }

  build() {
    SecondaryHdsDestination({
      title: '歌单详情',
      contentVariant: 'hero',
      content: this.buildContent
    })
  }
}
