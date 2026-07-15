import { PlaylistListView } from './PlaylistListView';
import { PlaybackPhase } from '../../playback/PlaybackSnapshot';
import { PlaylistSnapshot } from '../../playback/PlaylistSnapshot';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { PLAYLIST_SHEET_SCROLL_SEQ_KEY } from './PlaylistSheetState';

@Component
export struct PlaylistSheet {
  @StorageLink('playlist') @Watch('onPlaylistChanged') playlist: PlaylistSnapshot = PlaylistSnapshot.empty();
  @StorageProp('playbackTrackId') playingTrackId: string = '';
  @StorageProp('playbackPhase') playbackPhase: PlaybackPhase = 'idle';

  private onPlaylistChanged(): void {
    // PlaylistListView 内部通过 @Prop playlist 同步数据源
  }

  private queueSummary(): string {
    const count: number = this.playlist.items.length;
    if (this.playlist.currentIndex >= 0 && this.playlist.currentIndex < count) {
      return `${count} 首 · 当前第 ${this.playlist.currentIndex + 1} 首`;
    }
    return `${count} 首`;
  }

  private scrollToCurrent(): void {
    const current: number = AppStorage.get<number>(PLAYLIST_SHEET_SCROLL_SEQ_KEY) ?? 0;
    AppStorage.setOrCreate<number>(PLAYLIST_SHEET_SCROLL_SEQ_KEY, current + 1);
  }

  build() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('播放列表')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text(this.queueSummary())
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        if (this.playlist.currentIndex >= 0) {
          Button('定位当前')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_PRIMARY)
            .height(32)
            .padding({ left: 12, right: 12 })
            .backgroundColor(UiTokens.COLOR_CARD_BG)
            .borderRadius(10)
            .onClick(() => {
              this.scrollToCurrent();
            })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 48, top: 16, bottom: 12 })

      if (this.playlist.items.length === 0) {
        Column() {
          Text('播放列表为空')
            .fontSize(14)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          Text('从专辑菜单添加曲目，或点击歌曲开始播放')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 24, right: 24 })
      } else {
        PlaylistListView({
          playlist: this.playlist,
          highlightSongId: this.playingTrackId,
          playingTrackId: this.playingTrackId,
          playbackPhase: this.playbackPhase
        })
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, bottom: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(UiTokens.COLOR_PAGE_BG)
  }
}
