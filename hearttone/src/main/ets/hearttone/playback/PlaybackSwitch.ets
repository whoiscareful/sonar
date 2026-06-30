import { Album } from '../api/SubsonicTypes';
import { NowPlayingTrack } from './PlaybackSnapshot';

export interface PlaybackSwitchHost {
  submitCurrentTrackCompletionOnSwitch(): Promise<void>;
  stopHeartbeat(): void;
  lockPreview(track: NowPlayingTrack, albumCoverArtId?: string): void;
  stopEngineAndClearBuffers(): Promise<void>;
  loadCurrentSongStream(reportStart: boolean): Promise<void>;
  tryPromoteStandbyForSwitch(nextSongId: string): Promise<boolean>;
  finishPromotedSwitch(reportStart: boolean): Promise<void>;
  resetNextTrackPreload(): void;
  getSwitchTargetSongId(): string;
  clearPreview(): void;
  restoreSnapshotFromEngine(): void;
  buildPreviewTrackFromAlbum(album: Album): NowPlayingTrack;
}

/** 统一切歌：preview → stop → commit load（standby 命中时热路径 promote） */
export class PlaybackSwitch {
  static async prepareSwitch(
    host: PlaybackSwitchHost,
    previewTrack: NowPlayingTrack,
    albumCoverArtId?: string
  ): Promise<void> {
    await host.submitCurrentTrackCompletionOnSwitch();
    host.stopHeartbeat();
    host.lockPreview(previewTrack, albumCoverArtId);
    await host.stopEngineAndClearBuffers();
  }

  static async prepareSwitchFromAlbum(host: PlaybackSwitchHost, album: Album): Promise<void> {
    const previewTrack: NowPlayingTrack = host.buildPreviewTrackFromAlbum(album);
    await PlaybackSwitch.prepareSwitch(host, previewTrack, album.coverArt);
  }

  static async commitSwitch(host: PlaybackSwitchHost, reportStart: boolean): Promise<void> {
    const targetId: string = host.getSwitchTargetSongId();
    if (targetId.length > 0 && await host.tryPromoteStandbyForSwitch(targetId)) {
      await host.finishPromotedSwitch(reportStart);
    } else {
      await host.loadCurrentSongStream(reportStart);
    }
    host.resetNextTrackPreload();
  }

  static restoreFailedSwitch(host: PlaybackSwitchHost): void {
    host.clearPreview();
    host.restoreSnapshotFromEngine();
  }
}
