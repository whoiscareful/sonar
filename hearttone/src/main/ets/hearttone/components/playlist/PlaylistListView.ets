import { Song } from '../../api/SubsonicTypes';
import { PlaybackPhase } from '../../playback/PlaybackSnapshot';
import { PlaylistSnapshot } from '../../playback/PlaylistSnapshot';
import { MusicListRow } from '../lists/MusicListView';
import { PLAYLIST_SHEET_SCROLL_SEQ_KEY } from './PlaylistSheetController';
import { PlaylistDataSource } from './PlaylistDataSource';

@Component
export struct PlaylistListView {
  @Prop @Watch('onPlaylistChanged') playlist: PlaylistSnapshot = PlaylistSnapshot.empty();
  @Prop highlightSongId: string = '';
  @Prop playingTrackId: string = '';
  @Prop playbackPhase: PlaybackPhase = 'idle';
  @StorageProp(PLAYLIST_SHEET_SCROLL_SEQ_KEY) @Watch('onScrollRequest') private scrollSeq: number = 0;

  private scroller: ListScroller = new ListScroller();
  private dataSource: PlaylistDataSource = new PlaylistDataSource();

  aboutToAppear(): void {
    this.syncDataSource();
    this.scrollToCurrent(this.playlist.currentIndex);
  }

  private onPlaylistChanged(): void {
    this.syncDataSource();
  }

  private onScrollRequest(): void {
    if (this.scrollSeq <= 0) {
      return;
    }
    this.scrollToCurrent(this.playlist.currentIndex);
  }

  private syncDataSource(): void {
    this.dataSource.setSongs(this.playlist.items);
  }

  private scrollToCurrent(index: number): void {
    if (index < 0 || index >= this.playlist.items.length) {
      return;
    }
    setTimeout(() => {
      this.scroller.scrollToIndex(index, true, ScrollAlign.CENTER);
    }, 120);
  }

  build() {
    List({ scroller: this.scroller, space: 0 }) {
      LazyForEach(this.dataSource, (song: Song, index: number) => {
        MusicListRow({
          song: song,
          index: index,
          highlightSongId: this.highlightSongId,
          playingTrackId: this.playingTrackId,
          playbackPhase: this.playbackPhase,
          showArtist: true,
          isLast: index >= this.playlist.items.length - 1
        })
      }, (song: Song, index: number) => `${index}_${song.id}`)
    }
    .width('100%')
    .layoutWeight(1)
    .cachedCount(8)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
