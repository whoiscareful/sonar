import { Song } from '../api/SubsonicTypes';

export type PlaybackMode = 'listLoop' | 'singleLoop' | 'random';

export type PlaybackPhase = 'idle' | 'loading' | 'playing' | 'paused' | 'error';

@Observed
export class NowPlayingTrack {
  readonly id: string;
  readonly title: string;
  readonly artist: string;
  readonly album: string;
  readonly coverArtId: string;
  readonly durationMs: number;

  constructor(id: string, title: string, artist: string, album: string, coverArtId: string, durationMs: number) {
    this.id = id;
    this.title = title;
    this.artist = artist;
    this.album = album;
    this.coverArtId = coverArtId;
    this.durationMs = durationMs;
  }
}

@Observed
export class PlaybackSnapshot {
  readonly track: NowPlayingTrack | null;
  readonly phase: PlaybackPhase;
  readonly positionMs: number;
  readonly mode: PlaybackMode;
  readonly showMiniPlayer: boolean;
  /** 封面 revision，CoverCache 异步加载后递增以触发 UI 刷新 */
  readonly coverRevision: number;
  /** 弱网 / 切网 rebuffer：phase 仍为 playing，进度冻结 */
  readonly isBuffering: boolean;

  constructor(
    track: NowPlayingTrack | null,
    phase: PlaybackPhase,
    positionMs: number,
    mode: PlaybackMode,
    showMiniPlayer: boolean,
    coverRevision: number,
    isBuffering: boolean = false
  ) {
    this.track = track;
    this.phase = phase;
    this.positionMs = positionMs;
    this.mode = mode;
    this.showMiniPlayer = showMiniPlayer;
    this.coverRevision = coverRevision;
    this.isBuffering = isBuffering;
  }

  static idle(mode: PlaybackMode = 'listLoop'): PlaybackSnapshot {
    return new PlaybackSnapshot(null, 'idle', 0, mode, false, 0, false);
  }

  isPlaying(): boolean {
    return this.phase === 'playing';
  }

  isLoading(): boolean {
    return this.phase === 'loading';
  }

  isCoverLoading(): boolean {
    return this.phase === 'loading' || this.isBuffering;
  }

  isProgressFrozen(): boolean {
    return this.phase === 'loading' || this.isBuffering;
  }
}

export function buildNowPlayingTrack(song: Song, albumCoverArtId?: string): NowPlayingTrack {
  let coverArtId: string = song.coverArt ?? '';
  if (coverArtId.length === 0 && albumCoverArtId !== undefined && albumCoverArtId.length > 0) {
    coverArtId = albumCoverArtId;
  }
  const durationMs: number = song.duration > 0 ? song.duration * 1000 : 0;
  return new NowPlayingTrack(
    song.id,
    song.title,
    song.artist,
    song.album,
    coverArtId,
    durationMs
  );
}
