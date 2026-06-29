import { common } from '@kit.AbilityKit';
import { avSession } from '@kit.AVSessionKit';
import { image } from '@kit.ImageKit';
import { Logger } from '../common/Logger';
import { NowPlayingTrack, PlaybackSnapshot } from './PlaybackSnapshot';

interface MediaCenterAvPlayback {
  state: avSession.PlaybackState;
  speed: number;
}

export interface MediaCenterCommands {
  onPlay: () => Promise<void>;
  onPause: () => Promise<void>;
  onNext: () => Promise<void>;
  onPrevious: () => Promise<void>;
  onSeek: (positionMs: number) => Promise<void>;
}

export class MediaCenter {
  private context: common.UIAbilityContext | null = null;
  private session: avSession.AVSession | null = null;
  private commands: MediaCenterCommands | null = null;
  private eventsRegistered: boolean = false;
  private activated: boolean = false;
  private lastAssetId: string = '';
  private lastMetadataCoverArtId: string = '';
  private lastMetadataDurationMs: number = 0;
  private lastPlaybackSyncSecond: number = -1;
  private lastPlaybackStateIsPlaying: boolean = false;
  private lastPlaybackStateSyncAt: number = 0;
  private playbackStateChain: Promise<void> = Promise.resolve();

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  setCommands(commands: MediaCenterCommands): void {
    this.commands = commands;
  }

  async apply(snapshot: PlaybackSnapshot, cover: image.PixelMap | null): Promise<void> {
    const session: avSession.AVSession | null = await this.ensureSession();
    if (session === null) {
      return;
    }
    const track = snapshot.track;
    if (track === null) {
      this.lastAssetId = '';
      this.lastMetadataCoverArtId = '';
      this.lastMetadataDurationMs = 0;
      try {
        await session.setAVPlaybackState({
          state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
          speed: 1.0,
          position: { elapsedTime: 0, updateTime: Date.now() }
        });
      } catch (err) {
        Logger.warn('MediaCenter', `clear state failed: ${(err as Error).message}`);
      }
      return;
    }
    const assetChanged: boolean = track.id !== this.lastAssetId;
    if (assetChanged) {
      this.lastAssetId = track.id;
      this.lastMetadataCoverArtId = '';
      this.lastMetadataDurationMs = 0;
    }
    if (MediaCenter.shouldUpdateMetadata(
      assetChanged, track, cover, this.lastMetadataCoverArtId, this.lastMetadataDurationMs)) {
      const metadata: avSession.AVMetadata = MediaCenter.buildMetadata(track, cover);
      try {
        await session.setAVMetadata(metadata);
        if (cover !== null && track.coverArtId.length > 0) {
          this.lastMetadataCoverArtId = track.coverArtId;
        }
        if (track.durationMs > 0) {
          this.lastMetadataDurationMs = track.durationMs;
        }
      } catch (err) {
        Logger.warn('MediaCenter', `setAVMetadata failed: ${(err as Error).message}`);
      }
    }
    await this.pushPlaybackState(snapshot, assetChanged);
    if (!this.activated) {
      try {
        await session.activate();
        this.activated = true;
      } catch (err) {
        Logger.warn('MediaCenter', `activate failed: ${(err as Error).message}`);
      }
    }
  }

  /** 仅同步播放进度/状态，不触发 setAVMetadata（供进度 tick 节流调用） */
  async syncPlaybackState(snapshot: PlaybackSnapshot): Promise<void> {
    const session: avSession.AVSession | null = await this.ensureSession();
    if (session === null || snapshot.track === null) {
      return;
    }
    await this.pushPlaybackState(snapshot, false);
  }

  async release(): Promise<void> {
    if (this.session === null) {
      return;
    }
    try {
      await this.session.deactivate();
    } catch (err) {
      Logger.warn('MediaCenter', `deactivate failed: ${(err as Error).message}`);
    }
    this.session = null;
    this.eventsRegistered = false;
    this.activated = false;
    this.lastAssetId = '';
    this.lastMetadataCoverArtId = '';
    this.lastMetadataDurationMs = 0;
    this.lastPlaybackSyncSecond = -1;
  }

  /** 仅在切歌、封面就绪或时长变化时更新元数据，避免进度同步重复 setAVMetadata */
  private static shouldUpdateMetadata(
    assetChanged: boolean,
    track: NowPlayingTrack,
    cover: image.PixelMap | null,
    lastCoverArtId: string,
    lastDurationMs: number
  ): boolean {
    if (assetChanged) {
      return true;
    }
    if (cover !== null && track.coverArtId.length > 0 && track.coverArtId !== lastCoverArtId) {
      return true;
    }
    if (track.durationMs > 0 && track.durationMs !== lastDurationMs) {
      if (lastCoverArtId.length > 0 && cover === null) {
        return false;
      }
      return true;
    }
    return false;
  }

  private static buildMetadata(track: NowPlayingTrack, cover: image.PixelMap | null): avSession.AVMetadata {
    if (cover !== null) {
      return {
        assetId: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.durationMs,
        mediaImage: cover
      };
    }
    return {
      assetId: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.durationMs
    };
  }

  private async pushPlaybackState(snapshot: PlaybackSnapshot, force: boolean): Promise<void> {
    const session: avSession.AVSession | null = this.session;
    if (session === null) {
      return;
    }
    const avState: MediaCenterAvPlayback = MediaCenter.resolveAvPlaybackState(snapshot);
    const isPlaying: boolean = avState.state === avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    const positionMs: number = snapshot.positionMs;
    const now: number = Date.now();
    const currentSecond: number = Math.floor(positionMs / 1000);
    if (snapshot.isBuffering) {
      this.playbackStateChain = this.playbackStateChain.then(async (): Promise<void> => {
        try {
          await session.setAVPlaybackState({
            state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
            speed: 1.0,
            position: {
              elapsedTime: positionMs,
              updateTime: now
            }
          });
          this.lastPlaybackStateSyncAt = now;
          this.lastPlaybackStateIsPlaying = false;
          this.lastPlaybackSyncSecond = currentSecond;
        } catch (err) {
          Logger.warn('MediaCenter', `buffering pause state failed: ${(err as Error).message}`);
        }
      });
      await this.playbackStateChain;
      return;
    }
    if (!force && isPlaying && currentSecond === this.lastPlaybackSyncSecond) {
      return;
    } else if (!force && isPlaying === this.lastPlaybackStateIsPlaying &&
      now - this.lastPlaybackStateSyncAt < 1000) {
      return;
    }
    this.playbackStateChain = this.playbackStateChain.then(async (): Promise<void> => {
      try {
        await session.setAVPlaybackState({
          state: avState.state,
          speed: avState.speed,
          position: {
            elapsedTime: positionMs,
            updateTime: now
          }
        });
        this.lastPlaybackStateSyncAt = now;
        this.lastPlaybackStateIsPlaying = isPlaying;
        this.lastPlaybackSyncSecond = currentSecond;
      } catch (err) {
        Logger.warn('MediaCenter', `setAVPlaybackState failed: ${(err as Error).message}`);
      }
    });
    await this.playbackStateChain;
  }

  /**
   * 系统播控在 PLAY 下会 extrapolate 进度。rebuffer/切网对系统上报 PAUSE + 冻结位置；
   * 应用内仍保持 phase=playing + isBuffering（封面 loading）。
   */
  private static resolveAvPlaybackState(snapshot: PlaybackSnapshot): MediaCenterAvPlayback {
    if (snapshot.isBuffering) {
      return {
        state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
        speed: 1.0
      };
    }
    if (snapshot.phase === 'playing') {
      return {
        state: avSession.PlaybackState.PLAYBACK_STATE_PLAY,
        speed: 1.0
      };
    }
    if (snapshot.phase === 'loading') {
      return {
        state: avSession.PlaybackState.PLAYBACK_STATE_PREPARE,
        speed: 1.0
      };
    }
    if (snapshot.phase === 'paused') {
      return {
        state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
        speed: 1.0
      };
    }
    return {
      state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      speed: 1.0
    };
  }

  private async ensureSession(): Promise<avSession.AVSession | null> {
    if (this.session !== null) {
      return this.session;
    }
    if (this.context === null) {
      return null;
    }
    try {
      const created: avSession.AVSession =
        await avSession.createAVSession(this.context, 'sonar_audio_session', 'audio');
      this.registerEvents(created);
      this.session = created;
      try {
        created.off('toggleFavorite');
      } catch (_err) {
      }
      return created;
    } catch (err) {
      Logger.warn('MediaCenter', `createAVSession failed: ${(err as Error).message}`);
      return null;
    }
  }

  private registerEvents(session: avSession.AVSession): void {
    if (this.eventsRegistered) {
      return;
    }
    try {
      session.on('play', () => {
        if (this.commands !== null) {
          void this.commands.onPlay();
        }
      });
    } catch (err) {
      Logger.warn('MediaCenter', `register play failed: ${(err as Error).message}`);
    }
    try {
      session.on('pause', () => {
        if (this.commands !== null) {
          void this.commands.onPause();
        }
      });
    } catch (err) {
      Logger.warn('MediaCenter', `register pause failed: ${(err as Error).message}`);
    }
    try {
      session.on('playNext', () => {
        if (this.commands !== null) {
          void this.commands.onNext();
        }
      });
    } catch (err) {
      Logger.warn('MediaCenter', `register playNext failed: ${(err as Error).message}`);
    }
    try {
      session.on('playPrevious', () => {
        if (this.commands !== null) {
          void this.commands.onPrevious();
        }
      });
    } catch (err) {
      Logger.warn('MediaCenter', `register playPrevious failed: ${(err as Error).message}`);
    }
    try {
      session.on('seek', (timeMs: number) => {
        if (this.commands !== null) {
          void this.commands.onSeek(timeMs);
        }
      });
    } catch (err) {
      Logger.warn('MediaCenter', `register seek failed: ${(err as Error).message}`);
    }
    this.eventsRegistered = true;
  }
}
