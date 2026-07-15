import { Song } from '../../api/SubsonicTypes';
import { PlaybackPhase } from '../../playback/PlaybackSnapshot';
import { PlaylistSnapshot } from '../../playback/PlaylistSnapshot';
import { MusicListRow } from '../lists/MusicListView';
import { PLAYLIST_SHEET_SCROLL_SEQ_KEY } from './PlaylistSheetState';
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
  private lastCurrentIndex: number = -1;
  private pendingScrollTimerId: number | null = null;
  private isUserScrolling: boolean = false;

  aboutToAppear(): void {
    this.syncDataSource();
    this.lastCurrentIndex = this.playlist.currentIndex;
    this.scrollToCurrent(this.playlist.currentIndex, false);
  }

  aboutToDisappear(): void {
    this.cancelPendingScroll();
  }

  private onPlaylistChanged(): void {
    this.syncDataSource();
    if (this.playlist.currentIndex !== this.lastCurrentIndex) {
      this.lastCurrentIndex = this.playlist.currentIndex;
      if (!this.isUserScrolling) {
        this.scrollToCurrent(this.playlist.currentIndex, true);
      }
    }
  }

  private onScrollRequest(): void {
    if (this.scrollSeq <= 0) {
      return;
    }
    this.scrollToCurrent(this.playlist.currentIndex, true);
  }

  private syncDataSource(): void {
    this.dataSource.setSongs(this.playlist.items);
  }

  private scrollToCurrent(index: number, smooth: boolean): void {
    if (index < 0 || index >= this.playlist.items.length) {
      return;
    }
    this.cancelPendingScroll();
    this.pendingScrollTimerId = setTimeout(() => {
      this.pendingScrollTimerId = null;
      this.scroller.scrollToIndex(index, smooth, ScrollAlign.CENTER);
    }, 80) as number;
  }

  private cancelPendingScroll(): void {
    if (this.pendingScrollTimerId !== null) {
      clearTimeout(this.pendingScrollTimerId);
      this.pendingScrollTimerId = null;
    }
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
    .onScrollStart(() => {
      this.isUserScrolling = true;
    })
    .onScrollStop(() => {
      this.isUserScrolling = false;
    })
  }
}
