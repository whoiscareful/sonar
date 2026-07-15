import { CoverCacheStore } from '../cache/CoverCacheStore';
import { SongCache } from '../cache/SongCache';
import { SongCacheStore } from '../cache/SongCacheStore';
import { CardContainer } from '../components/layout/CardContainer';
import { CoverCache } from '../playback/CoverCache';
import { ProfileAppearanceStore } from '../settings/ProfileAppearanceStore';
import { RecentPlayHistoryStore } from '../settings/RecentPlayHistoryStore';
import { UserPlaylistStore } from '../settings/UserPlaylistStore';
import { PlaylistArtworkStore } from '../settings/PlaylistArtworkStore';
import { UiTokens } from '../ui/tokens/UiTokens';

@Component
export struct DataManagementPage {
  @StorageLink('songCacheUsedBytes') songCacheUsedBytes: number = 0;
  @StorageLink('coverCacheUsedBytes') coverCacheUsedBytes: number = 0;
  @StorageLink('profileAppearanceRevision') profileAppearanceRevision: number = 0;
  @State private listeningRecordCount: number = 0;
  @State private playlistCount: number = 0;
  @State private hasPersonalAppearance: boolean = false;
  @State private busyKey: string = '';
  private readonly appearanceStore: ProfileAppearanceStore = ProfileAppearanceStore.getInstance();

  aboutToAppear(): void {
    void this.refreshState();
  }

  private async refreshState(): Promise<void> {
    this.songCacheUsedBytes = SongCache.getTotalSizeBytes();
    this.coverCacheUsedBytes = CoverCache.getTotalSizeBytes();
    const history: RecentPlayHistoryStore = RecentPlayHistoryStore.getInstance();
    await history.ensureReady();
    this.listeningRecordCount = history.listListeningEvents(90).length;
    const playlistStore: UserPlaylistStore = UserPlaylistStore.getInstance();
    await playlistStore.ensureReady();
    this.playlistCount = playlistStore.list().length;
    this.hasPersonalAppearance = this.appearanceStore.avatarUri().length > 0 ||
      this.appearanceStore.coverUri().length > 0;
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
  }

  private async confirmDelete(title: string, message: string): Promise<boolean> {
    const result = await this.getUIContext().getPromptAction().showDialog({
      title: title,
      message: message,
      buttons: [
        { text: '取消', color: '#7A7F8A' },
        { text: '删除', color: '#D9485F' }
      ]
    });
    return result.index === 1;
  }

  private async performDelete(
    key: string,
    title: string,
    message: string,
    action: () => Promise<void>
  ): Promise<void> {
    if (this.busyKey.length > 0 || !await this.confirmDelete(title, message)) {
      return;
    }
    this.busyKey = key;
    try {
      await action();
      if (key === 'songs' || key === 'all') {
        this.songCacheUsedBytes = 0;
      }
      if (key === 'covers' || key === 'all') {
        this.coverCacheUsedBytes = 0;
      }
      if (key === 'history' || key === 'all') {
        this.listeningRecordCount = 0;
      }
      if (key === 'playlists' || key === 'all') {
        this.playlistCount = 0;
      }
      if (key === 'appearance' || key === 'all') {
        this.hasPersonalAppearance = false;
      }
      await this.refreshState();
      this.showToast('已删除');
    } catch (err) {
      this.showToast(`删除失败：${(err as Error).message}`);
    } finally {
      this.busyKey = '';
    }
  }

  private clearSongCache(): void {
    void this.performDelete(
      'songs',
      '删除歌曲缓存？',
      `将释放 ${SongCacheStore.formatBytes(this.songCacheUsedBytes)}，下次播放时需要重新下载。`,
      async (): Promise<void> => {
        await SongCache.clearAll();
      }
    );
  }

  private clearCoverCache(): void {
    void this.performDelete(
      'covers',
      '删除图片缓存？',
      `将释放 ${SongCacheStore.formatBytes(this.coverCacheUsedBytes)}，封面会在浏览时重新加载。`,
      async (): Promise<void> => {
        await CoverCache.clearAll();
      }
    );
  }

  private clearListeningHistory(): void {
    void this.performDelete(
      'history',
      '删除听歌记录？',
      '音乐统计和最近播放记录将被清空，此操作无法撤销。',
      async (): Promise<void> => {
        await RecentPlayHistoryStore.getInstance().clearAllData();
      }
    );
  }

  private clearPersonalAppearance(): void {
    void this.performDelete(
      'appearance',
      '删除个性化数据？',
      '本机头像、界面背景、图片 API 和背景效果将恢复默认。',
      async (): Promise<void> => {
        await this.appearanceStore.clearPersonalData();
      }
    );
  }

  private clearUserPlaylists(): void {
    void this.performDelete(
      'playlists',
      '删除本地歌单？',
      '本机创建和导入的歌单将被清空，服务器上的音乐不会受到影响。',
      async (): Promise<void> => {
        await UserPlaylistStore.getInstance().clearAllData();
        await PlaylistArtworkStore.getInstance().clearAllData();
      }
    );
  }

  private clearAllLocalData(): void {
    void this.performDelete(
      'all',
      '清除全部本地数据？',
      '歌曲缓存、图片缓存、听歌记录、本地歌单和个性化数据都会被删除。登录信息和服务器内容不受影响。',
      async (): Promise<void> => {
        await SongCache.clearAll();
        await CoverCache.clearAll();
        await RecentPlayHistoryStore.getInstance().clearAllData();
        await UserPlaylistStore.getInstance().clearAllData();
        await PlaylistArtworkStore.getInstance().clearAllData();
        await this.appearanceStore.clearPersonalData();
      }
    );
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .width('100%')
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
      .padding({ left: 2 })
  }

  @Builder
  private deleteRow(
    title: string,
    subtitle: string,
    key: string,
    action: () => void
  ) {
    Row({ space: 12 }) {
      Column() {
        Image($r('app.media.ic_data_management'))
          .width(20)
          .height(20)
          .fillColor(UiTokens.COLOR_DANGER)
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(11)
      .backgroundColor(UiTokens.COLOR_DANGER_SOFT_BG)

      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(subtitle)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.busyKey === key) {
        LoadingProgress()
          .width(19)
          .height(19)
          .color(UiTokens.COLOR_DANGER)
      } else {
        Button('删除')
          .height(32)
          .padding({ left: 11, right: 11 })
          .fontSize(12)
          .fontColor(UiTokens.COLOR_DANGER)
          .backgroundColor(UiTokens.COLOR_DANGER_SOFT_BG)
          .borderRadius(10)
          .enabled(this.busyKey.length === 0)
          .onClick(() => {
            action();
          })
      }
    }
    .width('100%')
    .height(62)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column({ space: UiTokens.SECTION_GAP }) {
      this.sectionTitle('缓存数据')
      CardContainer() {
        Column() {
          this.deleteRow(
            '歌曲缓存',
            SongCacheStore.formatBytes(this.songCacheUsedBytes),
            'songs',
            () => { this.clearSongCache(); }
          )
          Divider().color(UiTokens.COLOR_CARD_BORDER).margin({ left: 50 })
          this.deleteRow(
            '专辑图片缓存',
            SongCacheStore.formatBytes(this.coverCacheUsedBytes),
            'covers',
            () => { this.clearCoverCache(); }
          )
        }
        .width('100%')
      }

      this.sectionTitle('个人数据')
      CardContainer() {
        Column() {
          this.deleteRow(
            '听歌记录',
            `${this.listeningRecordCount} 条有效播放记录`,
            'history',
            () => { this.clearListeningHistory(); }
          )
          Divider().color(UiTokens.COLOR_CARD_BORDER).margin({ left: 50 })
          this.deleteRow(
            '本地歌单',
            `${this.playlistCount} 个歌单`,
            'playlists',
            () => { this.clearUserPlaylists(); }
          )
          Divider().color(UiTokens.COLOR_CARD_BORDER).margin({ left: 50 })
          this.deleteRow(
            '个性化数据',
            this.hasPersonalAppearance ? '头像、背景与显示偏好' : '当前使用默认外观',
            'appearance',
            () => { this.clearPersonalAppearance(); }
          )
        }
        .width('100%')
      }

      this.sectionTitle('全部数据')
      CardContainer() {
        Column({ space: 8 }) {
          Text('清除本机产生的缓存、统计、歌单和个性化数据，不会删除服务器上的音乐，也不会退出登录。')
            .width('100%')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          Button('清除全部本地数据')
            .width('100%')
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
            .backgroundColor(UiTokens.COLOR_DANGER)
            .borderRadius(12)
            .enabled(this.busyKey.length === 0)
            .onClick(() => {
              this.clearAllLocalData();
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
  }
}
