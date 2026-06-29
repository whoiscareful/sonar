import { common } from '@kit.AbilityKit';
import { Album, Song } from '../api/SubsonicTypes';
import { PlaybackMode, PlaybackSnapshot } from './PlaybackSnapshot';
import { PlaylistSnapshot } from './PlaylistSnapshot';
import { PlaylistStore } from './PlaylistStore';
import { PlaybackSession, SystemTransportHandler } from './PlaybackSession';
import { PlaybackStore } from './PlaybackStore';

class ServiceTransportHandler implements SystemTransportHandler {
  async playNext(manual: boolean): Promise<void> {
    await PlaybackService.playNext(manual);
  }

  async playPrevious(): Promise<void> {
    await PlaybackService.playPrevious();
  }

  async seekTo(positionMs: number): Promise<void> {
    await PlaybackService.seekTo(positionMs);
  }

  async toggle(): Promise<void> {
    await PlaybackService.toggle();
  }
}

/** 播放域对外唯一入口（Facade） */
export class PlaybackService {
  private static readonly transportHandler: SystemTransportHandler = new ServiceTransportHandler();

  private static session(): PlaybackSession {
    return PlaybackSession.getInstance();
  }

  private static wireTransportHandlers(): void {
    PlaybackService.session().setTransportHandler(PlaybackService.transportHandler);
  }

  static async initialize(context: common.UIAbilityContext): Promise<void> {
    await PlaybackService.session().initialize(context);
    PlaybackService.wireTransportHandlers();
  }

  static setContext(context: common.UIAbilityContext): void {
    PlaybackService.session().setContext(context);
    PlaybackService.wireTransportHandlers();
  }

  static async release(): Promise<void> {
    await PlaybackService.session().release();
  }

  static async flushPersistence(): Promise<void> {
    await PlaybackService.session().flushPersistence();
  }

  static async playAlbumAll(album: Album): Promise<void> {
    await PlaybackService.session().playAlbumAll(album);
  }

  static async playQueue(songs: Song[], index: number, albumCoverArtId?: string): Promise<void> {
    await PlaybackService.session().playQueue(songs, index, albumCoverArtId);
  }

  static async enqueueNext(song: Song): Promise<void> {
    await PlaybackService.session().enqueueNext(song);
  }

  static async appendToPlaylist(songs: Song[]): Promise<number> {
    return PlaybackService.session().appendToPlaylist(songs);
  }

  static async appendAlbumToPlaylist(albumId: string): Promise<number> {
    return PlaybackService.session().appendAlbumToPlaylist(albumId);
  }

  static async playFromPlaylistIndex(index: number): Promise<void> {
    await PlaybackService.session().playFromPlaylistIndex(index);
  }

  static async removeFromPlaylist(index: number): Promise<void> {
    await PlaybackService.session().removeFromPlaylist(index);
  }

  static setPlaybackMode(mode: PlaybackMode): PlaybackMode {
    return PlaybackService.session().setPlaybackMode(mode);
  }

  static async toggle(): Promise<void> {
    await PlaybackService.session().toggle();
  }

  /**
   * 获取权威播放位置（实时计算，不受 snapshot 更新频率限制）
   */
  static getAuthoritativePositionMs(): number {
    return PlaybackService.session().getAuthoritativePositionMs();
  }

  static async playNext(manual: boolean = true): Promise<void> {
    await PlaybackService.session().playNext(manual);
  }

  static async playPrevious(): Promise<void> {
    await PlaybackService.session().playPrevious();
  }

  static async seekTo(positionMs: number): Promise<void> {
    await PlaybackService.session().seekTo(positionMs);
  }

  static togglePlaybackMode(): PlaybackMode {
    return PlaybackService.session().togglePlaybackMode();
  }

  static getSnapshot(): PlaybackSnapshot {
    return PlaybackStore.get();
  }

  static isSessionReady(): boolean {
    return PlaybackStore.isSessionReady();
  }

  static getPlaylistSnapshot(): PlaylistSnapshot {
    return PlaylistStore.get();
  }
}
