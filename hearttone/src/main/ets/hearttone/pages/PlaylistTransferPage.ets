import { Song } from '../api/SubsonicTypes';
import { CardContainer } from '../components/layout/CardContainer';
import { SecondaryHdsDestination } from '../components/navigation/SecondaryHdsDestination';
import {
  UserPlaylist,
  UserPlaylistStore,
  UserPlaylistTransferResult
} from '../settings/UserPlaylistStore';
import { UiTokens } from '../ui/tokens/UiTokens';

export interface PlaylistTransferRouteParam {
  sourcePlaylistId: string;
  sourcePlaylistName: string;
  sourceSystemFavorite: boolean;
  songs: Song[];
  move: boolean;
}

@Component
export struct PlaylistTransferPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink('userPlaylistRevision') @Watch('onPlaylistRevision') userPlaylistRevision: number = 0;
  @State private sourcePlaylistId: string = '';
  @State private sourcePlaylistName: string = '';
  @State private sourceSystemFavorite: boolean = false;
  @State private songs: Song[] = [];
  @State private move: boolean = false;
  @State private playlists: UserPlaylist[] = [];
  @State private searchText: string = '';
  @State private busyPlaylistId: string = '';
  @State private loading: boolean = true;

  async aboutToAppear(): Promise<void> {
    const currentIndex: number = this.appPathStack.size() - 1;
    const rawParam: Object | undefined = currentIndex >= 0 ?
      this.appPathStack.getParamByIndex(currentIndex) as Object : undefined;
    const param: PlaylistTransferRouteParam | undefined = rawParam as PlaylistTransferRouteParam | undefined;
    if (param === undefined || param.songs === undefined || param.songs.length === 0) {
      this.loading = false;
      this.showToast('没有可处理的歌曲');
      return;
    }
    this.sourcePlaylistId = param.sourcePlaylistId;
    this.sourcePlaylistName = param.sourcePlaylistName;
    this.sourceSystemFavorite = param.sourceSystemFavorite;
    this.songs = param.songs;
    this.move = param.move && !param.sourceSystemFavorite;
    await this.refresh();
  }

  private onPlaylistRevision(): void {
    this.playlists = UserPlaylistStore.getInstance().list();
  }

  private async refresh(): Promise<void> {
    this.loading = true;
    await UserPlaylistStore.getInstance().ensureReady();
    this.playlists = UserPlaylistStore.getInstance().list();
    this.loading = false;
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
  }

  private visibleTargets(): UserPlaylist[] {
    const keyword: string = this.searchText.trim().toLowerCase();
    const result: UserPlaylist[] = [];
    for (let i: number = 0; i < this.playlists.length; i++) {
      const playlist: UserPlaylist = this.playlists[i];
      if (playlist.id === this.sourcePlaylistId) {
        continue;
      }
      if (keyword.length === 0 || playlist.name.toLowerCase().includes(keyword) ||
        playlist.description.toLowerCase().includes(keyword)) {
        result.push(playlist);
      }
    }
    return result;
  }

  private async applyTransfer(target: UserPlaylist): Promise<void> {
    if (this.busyPlaylistId.length > 0) {
      return;
    }
    this.busyPlaylistId = target.id;
    try {
      let added: number = 0;
      let removed: number = 0;
      const store: UserPlaylistStore = UserPlaylistStore.getInstance();
      if (this.sourceSystemFavorite) {
        added = await store.addSongs(target.id, this.songs);
      } else {
        const songIds: string[] = this.songs.map((song: Song): string => song.id);
        const result: UserPlaylistTransferResult = await store.transferSongs(
          this.sourcePlaylistId, target.id, songIds, this.move);
        added = result.added;
        removed = result.removed;
      }
      if (this.move && removed > 0) {
        this.showToast(`已移动 ${removed} 首到「${target.name}」`);
      } else if (added > 0) {
        this.showToast(`已复制 ${added} 首到「${target.name}」`);
      } else {
        this.showToast('目标歌单已包含所选歌曲');
      }
      if (added > 0 || removed > 0) {
        this.appPathStack.pop();
      }
    } catch (err) {
      this.showToast(`操作失败：${(err as Error).message}`);
    } finally {
      this.busyPlaylistId = '';
    }
  }

  @Builder
  private targetCard(playlist: UserPlaylist) {
    CardContainer() {
      Row({ space: 12 }) {
        Column() {
          Image($r('app.media.ic_playlist_library'))
            .width(22)
            .height(22)
            .fillColor(UiTokens.COLOR_PRIMARY)
        }
        .width(42)
        .height(42)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(9)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)

        Column({ space: 3 }) {
          Text(playlist.name)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${playlist.songs.length} 首${playlist.description.length > 0 ? ` · ${playlist.description}` : ''}`)
            .fontSize(10)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.busyPlaylistId === playlist.id) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(UiTokens.COLOR_PRIMARY)
        } else {
          Button(this.move ? '移动' : '复制')
            .height(34)
            .padding({ left: 12, right: 12 })
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
            .backgroundColor(UiTokens.COLOR_PRIMARY)
            .borderRadius(8)
            .enabled(this.busyPlaylistId.length === 0)
            .onClick(() => {
              void this.applyTransfer(playlist);
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @LocalBuilder
  private buildContent() {
    Column({ space: 12 }) {
      Column({ space: 3 }) {
        Text(this.move ? '移动歌曲' : '复制歌曲')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(`从「${this.sourcePlaylistName}」选择了 ${this.songs.length} 首，请选择目标歌单`)
          .width('100%')
          .fontSize(11)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .maxLines(2)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      TextInput({ text: this.searchText, placeholder: '搜索目标歌单' })
        .width('100%')
        .height(40)
        .fontSize(13)
        .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        .borderRadius(9)
        .onChange((value: string) => {
          this.searchText = value;
        })

      if (this.loading) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(UiTokens.COLOR_PRIMARY)
          .alignSelf(ItemAlign.Center)
          .margin({ top: 32 })
      } else if (this.visibleTargets().length === 0) {
        Text(this.playlists.length <= 1 ? '请先创建另一个本地歌单' : '没有匹配的目标歌单')
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontSize(13)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          .padding({ top: 32, bottom: 32 })
      } else {
        ForEach(this.visibleTargets(), (playlist: UserPlaylist) => {
          this.targetCard(playlist)
        }, (playlist: UserPlaylist) => playlist.id)
      }
    }
    .width('100%')
  }

  build() {
    SecondaryHdsDestination({
      title: this.move ? '移动歌曲' : '复制歌曲',
      content: this.buildContent
    })
  }
}
