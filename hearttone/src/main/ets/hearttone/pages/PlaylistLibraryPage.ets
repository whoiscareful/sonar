import { Song } from '../api/SubsonicTypes';
import { CoverDisplayResolver } from '../cache/CoverDisplayResolver';
import { CardContainer } from '../components/layout/CardContainer';
import { MusicCatalogRepository } from '../domain/music/MusicCatalogRepository';
import { PlaybackService } from '../playback/PlaybackService';
import { PlaylistArtwork, PlaylistArtworkStore } from '../settings/PlaylistArtworkStore';
import { UserPlaylist, UserPlaylistStore } from '../settings/UserPlaylistStore';
import { UiTokens } from '../ui/tokens/UiTokens';
import { PlaylistDetailRouteParam } from './PlaylistDetailPage';

type PlaylistSortMode = 'updated' | 'name' | 'count';

@Component
export struct PlaylistLibraryPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink('userPlaylistRevision') @Watch('onPlaylistRevision') userPlaylistRevision: number = 0;
  @StorageLink('favoriteRevision') @Watch('onFavoriteRevision') favoriteRevision: number = 0;
  @StorageLink('playlistArtworkRevision') playlistArtworkRevision: number = 0;
  @State private playlists: UserPlaylist[] = [];
  @State private favoriteSongs: Song[] = [];
  @State private loading: boolean = true;
  @State private actionPlaylistId: string = '';
  @State private searchText: string = '';
  @State private sortMode: PlaylistSortMode = 'updated';
  @State private selectionMode: boolean = false;
  @State private selectedPlaylistIds: string[] = [];
  @State private longPressedPlaylistId: string = '';

  aboutToAppear(): void {
    void this.refresh();
  }

  private onPlaylistRevision(): void {
    this.playlists = UserPlaylistStore.getInstance().list();
    this.pruneSelection();
  }

  private onFavoriteRevision(): void {
    void this.refreshFavoriteSongs();
  }

  private async refreshFavoriteSongs(): Promise<void> {
    try {
      this.favoriteSongs = await MusicCatalogRepository.getInstance().favoriteSongs();
    } catch (_err) {
      this.favoriteSongs = [];
    }
  }

  private async refresh(): Promise<void> {
    this.loading = true;
    await UserPlaylistStore.getInstance().ensureReady();
    await PlaylistArtworkStore.getInstance().ensureReady();
    this.playlists = UserPlaylistStore.getInstance().list();
    await this.refreshFavoriteSongs();
    this.loading = false;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1600 });
    } catch (_err) {
    }
  }

  private openDetail(id: string, name: string, systemFavorite: boolean): void {
    const param: PlaylistDetailRouteParam = {
      playlistId: id,
      playlistName: name,
      systemFavorite: systemFavorite
    };
    this.appPathStack.pushPathByName('PlaylistDetailPage', param);
  }

  private artworkUri(id: string): string {
    const artwork: PlaylistArtwork = PlaylistArtworkStore.getInstance().artworkFor(id);
    if (artwork.imageUri.length > 0) {
      return artwork.imageUri;
    }
    return artwork.coverArtId.length > 0 ? CoverDisplayResolver.resolve(artwork.coverArtId, 160) ?? '' : '';
  }

  private playlistSummary(playlist: UserPlaylist): string {
    if (playlist.description.length > 0) {
      return playlist.description;
    }
    if (playlist.songs.length === 0) {
      return '空歌单';
    }
    const names: string[] = [];
    const count: number = Math.min(2, playlist.songs.length);
    for (let i: number = 0; i < count; i++) {
      names.push(playlist.songs[i].title);
    }
    return names.join(' · ');
  }

  private visiblePlaylists(): UserPlaylist[] {
    const keyword: string = this.searchText.trim().toLowerCase();
    const result: UserPlaylist[] = [];
    for (let i: number = 0; i < this.playlists.length; i++) {
      const playlist: UserPlaylist = this.playlists[i];
      if (keyword.length === 0 || this.matchesPlaylist(playlist, keyword)) {
        result.push(playlist);
      }
    }
    result.sort((left: UserPlaylist, right: UserPlaylist): number => {
      if (this.sortMode === 'name') {
        return left.name.localeCompare(right.name);
      }
      if (this.sortMode === 'count') {
        return right.songs.length - left.songs.length;
      }
      return right.updatedAt - left.updatedAt;
    });
    return result;
  }

  private matchesPlaylist(playlist: UserPlaylist, keyword: string): boolean {
    if (playlist.name.toLowerCase().includes(keyword) ||
      playlist.description.toLowerCase().includes(keyword)) {
      return true;
    }
    for (let i: number = 0; i < playlist.songs.length; i++) {
      const song: Song = playlist.songs[i];
      if (song.title.toLowerCase().includes(keyword) || song.artist.toLowerCase().includes(keyword)) {
        return true;
      }
    }
    return false;
  }

  private showFavorite(): boolean {
    const keyword: string = this.searchText.trim().toLowerCase();
    if (keyword.length === 0 || '喜爱'.includes(keyword)) {
      return true;
    }
    for (let i: number = 0; i < this.favoriteSongs.length; i++) {
      if (this.favoriteSongs[i].title.toLowerCase().includes(keyword) ||
        this.favoriteSongs[i].artist.toLowerCase().includes(keyword)) {
        return true;
      }
    }
    return false;
  }

  private sortLabel(): string {
    if (this.sortMode === 'name') {
      return '名称';
    }
    if (this.sortMode === 'count') {
      return '歌曲数';
    }
    return '最近更新';
  }

  private async chooseSort(): Promise<void> {
    const result = await this.getUIContext().getPromptAction().showActionMenu({
      title: '歌单排序',
      buttons: [
        { text: '最近更新', color: '#1C1C1E' },
        { text: '名称', color: '#1C1C1E' },
        { text: '歌曲数', color: '#1C1C1E' }
      ]
    });
    if (result.index === 0) {
      this.sortMode = 'updated';
    } else if (result.index === 1) {
      this.sortMode = 'name';
    } else if (result.index === 2) {
      this.sortMode = 'count';
    }
  }

  private async play(playlist: UserPlaylist): Promise<void> {
    if (playlist.songs.length === 0 || this.actionPlaylistId.length > 0 || this.selectionMode) {
      return;
    }
    this.actionPlaylistId = playlist.id;
    try {
      await PlaybackService.playQueue(playlist.songs, 0);
      this.showToast(`正在播放「${playlist.name}」`);
    } catch (err) {
      this.showToast((err as Error).message || '播放失败');
    } finally {
      this.actionPlaylistId = '';
    }
  }

  private async playFavorite(): Promise<void> {
    if (this.favoriteSongs.length === 0 || this.actionPlaylistId.length > 0 || this.selectionMode) {
      return;
    }
    this.actionPlaylistId = 'favorite';
    try {
      await PlaybackService.playQueue(this.favoriteSongs, 0);
      this.showToast('正在播放「喜爱」');
    } catch (err) {
      this.showToast((err as Error).message || '播放失败');
    } finally {
      this.actionPlaylistId = '';
    }
  }

  private async remove(playlist: UserPlaylist): Promise<void> {
    if (this.actionPlaylistId.length > 0 || this.selectionMode) {
      return;
    }
    const result = await this.getUIContext().getPromptAction().showDialog({
      title: '删除歌单？',
      message: `「${playlist.name}」将从本机删除，曲库中的歌曲不会受到影响。`,
      buttons: [
        { text: '取消', color: '#7A7F8A' },
        { text: '删除', color: '#D9485F' }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    this.actionPlaylistId = playlist.id;
    try {
      await UserPlaylistStore.getInstance().remove(playlist.id);
      await PlaylistArtworkStore.getInstance().clear(playlist.id);
      this.showToast('歌单已删除');
    } finally {
      this.actionPlaylistId = '';
    }
  }

  private isSelected(id: string): boolean {
    return this.selectedPlaylistIds.indexOf(id) >= 0;
  }

  private toggleSelection(id: string): void {
    const index: number = this.selectedPlaylistIds.indexOf(id);
    if (index >= 0) {
      this.selectedPlaylistIds = this.selectedPlaylistIds.filter((item: string) => item !== id);
    } else {
      this.selectedPlaylistIds = this.selectedPlaylistIds.concat([id]);
    }
  }

  private enterSelection(id: string): void {
    this.longPressedPlaylistId = id;
    this.selectionMode = true;
    if (!this.isSelected(id)) {
      this.selectedPlaylistIds = this.selectedPlaylistIds.concat([id]);
    }
  }

  private handlePlaylistClick(playlist: UserPlaylist): void {
    if (this.longPressedPlaylistId === playlist.id) {
      this.longPressedPlaylistId = '';
      return;
    }
    if (this.selectionMode) {
      this.toggleSelection(playlist.id);
      return;
    }
    this.openDetail(playlist.id, playlist.name, false);
  }

  private toggleSelectAll(): void {
    const visible: UserPlaylist[] = this.visiblePlaylists();
    let allSelected: boolean = visible.length > 0;
    for (let i: number = 0; i < visible.length; i++) {
      if (!this.isSelected(visible[i].id)) {
        allSelected = false;
        break;
      }
    }
    if (allSelected) {
      const visibleIds: Set<string> = new Set<string>();
      for (let i: number = 0; i < visible.length; i++) {
        visibleIds.add(visible[i].id);
      }
      this.selectedPlaylistIds = this.selectedPlaylistIds.filter((id: string) => !visibleIds.has(id));
      return;
    }
    const nextIds: Set<string> = new Set<string>(this.selectedPlaylistIds);
    for (let i: number = 0; i < visible.length; i++) {
      nextIds.add(visible[i].id);
    }
    this.selectedPlaylistIds = Array.from(nextIds);
  }

  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedPlaylistIds = [];
    this.longPressedPlaylistId = '';
  }

  private pruneSelection(): void {
    const availableIds: Set<string> = new Set<string>();
    for (let i: number = 0; i < this.playlists.length; i++) {
      availableIds.add(this.playlists[i].id);
    }
    this.selectedPlaylistIds = this.selectedPlaylistIds.filter((id: string) => availableIds.has(id));
    if (this.selectionMode && this.selectedPlaylistIds.length === 0) {
      this.exitSelection();
    }
  }

  private async removeSelected(): Promise<void> {
    if (this.selectedPlaylistIds.length === 0 || this.actionPlaylistId.length > 0) {
      return;
    }
    const result = await this.getUIContext().getPromptAction().showDialog({
      title: `删除 ${this.selectedPlaylistIds.length} 个歌单？`,
      message: '所选本地歌单及其自定义封面会被删除，曲库中的歌曲不会受到影响。',
      buttons: [
        { text: '取消', color: '#7A7F8A' },
        { text: '删除', color: '#D9485F' }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    this.actionPlaylistId = 'batch';
    try {
      const ids: string[] = this.selectedPlaylistIds.slice();
      const removed: number = await UserPlaylistStore.getInstance().removeMany(ids);
      await PlaylistArtworkStore.getInstance().clearMany(ids);
      this.exitSelection();
      this.showToast(`已删除 ${removed} 个歌单`);
    } finally {
      this.actionPlaylistId = '';
    }
  }

  @Builder
  private playlistCard(playlist: UserPlaylist) {
    CardContainer() {
      Row({ space: 12 }) {
        if (this.selectionMode) {
          Checkbox({ name: `playlist-${playlist.id}`, group: 'playlist-selection' })
            .select(this.isSelected(playlist.id))
            .selectedColor(UiTokens.COLOR_PRIMARY)
            .width(26)
            .height(26)
            .hitTestBehavior(HitTestMode.None)
        }

        Stack({ alignContent: Alignment.Center }) {
          if (this.artworkUri(playlist.id).length > 0) {
            Image(this.artworkUri(playlist.id))
              .width(48)
              .height(48)
              .borderRadius(13)
              .objectFit(ImageFit.Cover)
          } else {
            Column()
              .width(48)
              .height(48)
              .borderRadius(13)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            Image($r('app.media.ic_playlist_library'))
              .width(23)
              .height(23)
              .fillColor(UiTokens.COLOR_PRIMARY)
          }
        }
        .width(48)
        .height(48)

        Column({ space: 4 }) {
          Text(playlist.name)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${playlist.songs.length} 首 · ${this.playlistSummary(playlist)}`)
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (!this.selectionMode) {
          if (this.actionPlaylistId === playlist.id) {
            LoadingProgress().width(21).height(21).color(UiTokens.COLOR_PRIMARY)
          } else {
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.cb_play'))
                .width(16)
                .height(16)
                .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
            }
            .width(34)
            .height(34)
            .backgroundColor(UiTokens.COLOR_PRIMARY)
            .enabled(playlist.songs.length > 0)
            .onClick(() => {
              void this.play(playlist);
            })
            Button('删除')
              .height(32)
              .padding({ left: 9, right: 9 })
              .fontSize(11)
              .fontColor(UiTokens.COLOR_DANGER)
              .backgroundColor(UiTokens.COLOR_DANGER_SOFT_BG)
              .borderRadius(9)
              .onClick(() => {
                void this.remove(playlist);
              })
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.handlePlaylistClick(playlist);
      })
      .gesture(
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction(() => {
            this.enterSelection(playlist.id);
          })
      )
    }
  }

  @Builder
  private favoriteCard() {
    CardContainer() {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.artworkUri('favorite').length > 0) {
            Image(this.artworkUri('favorite'))
              .width(48)
              .height(48)
              .borderRadius(13)
              .objectFit(ImageFit.Cover)
          } else {
            Column()
              .width(48)
              .height(48)
              .borderRadius(13)
              .backgroundColor(UiTokens.COLOR_DANGER_SOFT_BG)
            Image($r('app.media.ic_heart_filled'))
              .width(23)
              .height(23)
              .fillColor(UiTokens.COLOR_DANGER)
          }
        }
        .width(48)
        .height(48)

        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text('喜爱')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text('服务器')
              .fontSize(9)
              .fontColor(UiTokens.COLOR_DANGER)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor(UiTokens.COLOR_DANGER_SOFT_BG)
          }
          Text(`${this.favoriteSongs.length} 首 · 与服务器喜爱同步`)
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.actionPlaylistId === 'favorite') {
          LoadingProgress().width(21).height(21).color(UiTokens.COLOR_PRIMARY)
        } else {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.cb_play'))
              .width(16)
              .height(16)
              .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
          }
          .width(34)
          .height(34)
          .backgroundColor(UiTokens.COLOR_PRIMARY)
          .enabled(this.favoriteSongs.length > 0)
          .onClick(() => {
            void this.playFavorite();
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (!this.selectionMode) {
          this.openDetail('favorite', '喜爱', true);
        }
      })
    }
  }

  @Builder
  private normalToolbar() {
    Row() {
      Column({ space: 3 }) {
        Text('我的歌单')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(`${this.playlists.length + 1} 个歌单`)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Button() {
        Row({ space: 6 }) {
          Image($r('app.media.ic_playlist_add'))
            .width(17)
            .height(17)
            .fillColor(UiTokens.COLOR_TEXT_ON_BRAND)
          Text('新建与导入')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
        }
      }
      .height(36)
      .padding({ left: 12, right: 12 })
      .borderRadius(10)
      .backgroundColor(UiTokens.COLOR_PRIMARY)
      .onClick(() => {
        this.appPathStack.pushPathByName('PlaylistImportPage', null);
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private selectionToolbar() {
    Row({ space: 8 }) {
      Button('取消')
        .height(34)
        .fontSize(12)
        .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(8)
        .onClick(() => {
          this.exitSelection();
        })
      Text(`已选 ${this.selectedPlaylistIds.length} 项`)
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
      Button('全选')
        .height(34)
        .fontSize(12)
        .fontColor(UiTokens.COLOR_PRIMARY)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(8)
        .onClick(() => {
          this.toggleSelectAll();
        })
      Button('删除')
        .height(34)
        .fontSize(12)
        .fontColor(UiTokens.COLOR_DANGER)
        .backgroundColor(UiTokens.COLOR_DANGER_SOFT_BG)
        .borderRadius(8)
        .enabled(this.selectedPlaylistIds.length > 0 && this.actionPlaylistId.length === 0)
        .onClick(() => {
          void this.removeSelected();
        })
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private searchAndSort() {
    Row({ space: 8 }) {
      TextInput({ text: this.searchText, placeholder: '搜索歌单、描述或歌曲' })
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
    }
    .width('100%')
  }

  build() {
    Column({ space: UiTokens.SECTION_GAP }) {
      if (this.selectionMode) {
        this.selectionToolbar()
      } else {
        this.normalToolbar()
      }

      this.searchAndSort()

      if (this.loading) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(UiTokens.COLOR_PRIMARY)
          .alignSelf(ItemAlign.Center)
          .margin({ top: 42 })
      } else {
        if (!this.selectionMode && this.showFavorite()) {
          this.favoriteCard()
        }
        ForEach(this.visiblePlaylists(), (playlist: UserPlaylist) => {
          this.playlistCard(playlist)
        }, (playlist: UserPlaylist) => playlist.id)
        if ((!this.showFavorite() || this.selectionMode) && this.visiblePlaylists().length === 0) {
          Text(this.searchText.trim().length > 0 ? '没有匹配的歌单' : '暂无本地歌单')
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(13)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
            .padding({ top: 32, bottom: 32 })
        }
      }
    }
    .width('100%')
  }
}
