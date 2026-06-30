import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { Album, Song, SubsonicApiError } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { Logger } from '../common/Logger';
import { EndpointChangeEvent } from '../network/routing/EndpointTypes';
import { MediaResourceService } from '../network/media/MediaResourceService';
import { StreamResource } from '../network/media/StreamResource';
import { PlaySinkPhase } from './pipeline/AudioRenderSink';
import { PipelineOrchestrator, PipelineOrchestratorCallbacks } from './pipeline/PipelineOrchestrator';
import { PlaybackPipeline } from './pipeline/PlaybackPipeline';
import { BackgroundPlayback } from './BackgroundPlayback';
import { CoverCacheStore } from '../cache/CoverCacheStore';
import { SongCache } from '../cache/SongCache';
import { SongMetadataCache } from '../cache/SongMetadataCache';
import { SongCacheStore } from '../cache/SongCacheStore';
import { RecentPlayHistoryStore } from '../settings/RecentPlayHistoryStore';
import { CoverCache } from './CoverCache';
import { MediaCenter, MediaCenterCommands } from './MediaCenter';
import { resolveNextPlayback, resolvePreviousPlayback } from './PlaybackModeResolver';
import { EndpointRouter } from '../network/routing/EndpointRouter';
import { NextTrackPreloadCoordinator } from './preload/NextTrackPreloadCoordinator';
import { PreloadDeps } from './preload/NextTrackPreloadStrategy';
import { PreloadContext, resolvePreloadRemainingMs } from './preload/NextTrackPreloadTypes';
import { PreloadDeviceCapability } from './preload/PreloadDeviceCapability';
import {
  buildNowPlayingTrack,
  NowPlayingTrack,
  PlaybackMode,
  PlaybackPhase,
  PlaybackSnapshot
} from './PlaybackSnapshot';
import { PlaylistSnapshot } from './PlaylistSnapshot';
import { PlaylistStore } from './PlaylistStore';
import { PlaybackStore } from './PlaybackStore';
import { ShuffleController } from './ShuffleController';
import { PlaybackSwitch, PlaybackSwitchHost } from './PlaybackSwitch';
import { PlaylistPersistence } from './PlaylistPersistence';

const HEARTBEAT_INTERVAL_MS: number = 15_000;
const UI_POSITION_PUBLISH_INTERVAL_MS: number = 1000;
const MIN_SCROBBLE_TRACK_LENGTH_MS: number = 30_000;
const MAX_SCROBBLE_PROGRESS_THRESHOLD_MS: number = 240_000;

export interface SystemTransportHandler {
  playNext(manual: boolean): Promise<void>;
  playPrevious(): Promise<void>;
  seekTo(positionMs: number): Promise<void>;
  toggle(): Promise<void>;
}

class SessionMediaCenterCommands implements MediaCenterCommands {
  private readonly session: PlaybackSession;

  constructor(session: PlaybackSession) {
    this.session = session;
  }

  async onPlay(): Promise<void> {
    await this.session.handleSystemPlay();
  }

  async onPause(): Promise<void> {
    await this.session.handleSystemPause();
  }

  async onNext(): Promise<void> {
    const handler: SystemTransportHandler | null = this.session.getTransportHandler();
    if (handler !== null) {
      await handler.playNext(true);
    }
  }

  async onPrevious(): Promise<void> {
    const handler: SystemTransportHandler | null = this.session.getTransportHandler();
    if (handler !== null) {
      await handler.playPrevious();
    }
  }

  async onSeek(positionMs: number): Promise<void> {
    const handler: SystemTransportHandler | null = this.session.getTransportHandler();
    if (handler !== null) {
      await handler.seekTo(positionMs);
    }
  }
}

class SessionPipelineCallbacks implements PipelineOrchestratorCallbacks {
  private readonly session: PlaybackSession;

  constructor(session: PlaybackSession) {
    this.session = session;
  }

  onEnterBuffering(frozenPositionMs: number): void {
    this.session.onPipelineEnterBuffering(frozenPositionMs);
  }

  onExitBuffering(): void {
    this.session.onPipelineExitBuffering();
  }

  onPhaseChanged(phase: PlaySinkPhase): void {
    this.session.onPipelinePhase(phase);
  }

  onPositionChanged(positionMs: number): void {
    this.session.onPipelinePosition(positionMs);
  }

  onDurationChanged(durationMs: number): void {
    this.session.onPipelineDuration(durationMs);
  }

  onCompleted(): void {
    void this.session.handleTrackCompleted();
  }

  onError(message: string): void {
    this.session.handlePipelineError(message);
  }

  getAuthoritativePositionMs(): number {
    return this.session.getAuthoritativePositionMs();
  }

  getCurrentPhase(): string {
    return this.session.snapshot.phase;
  }
}

export class PlaybackSession implements PlaybackSwitchHost {
  private static instance: PlaybackSession | null = null;

  private initialized: boolean = false;
  private initPromise: Promise<void> | null = null;
  private context: common.UIAbilityContext | null = null;
  private readonly orchestrator: PipelineOrchestrator = new PipelineOrchestrator();
  private readonly mediaCenter: MediaCenter = new MediaCenter();
  private displayQueue: Song[] = [];
  private currentIndex: number = -1;
  private currentMode: PlaybackMode = 'listLoop';
  private shuffleOrder: number[] = [];
  private shuffleCursor: number = 0;
  private playlistRevision: number = 0;
  private cachedPublishedItems: Song[] = [];
  private coverRevision: number = 0;
  private currentCover: image.PixelMap | null = null;
  private currentCoverId: string = '';
  private heartbeatTimerId: number = -1;
  private handlingCompletion: boolean = false;
  private systemCommandInFlight: boolean = false;
  private albumCoverFallbackId: string = '';
  snapshot: PlaybackSnapshot = PlaybackSnapshot.idle();
  private previewTrack: NowPlayingTrack | null = null;
  /** 点播后、Session init 完成前暂存的预览曲，用于 miniBar 封面 loading */
  private stagedPlayPreview: NowPlayingTrack | null = null;
  private transportHandler: SystemTransportHandler | null = null;
  private lastMediaCenterPositionAt: number = 0;
  private activeStreamResource: StreamResource | null = null;
  private isBuffering: boolean = false;
  private frozenPositionMs: number = 0;
  private pipelinePhase: PlaybackPhase = 'idle';
  private preloadCoordinator: NextTrackPreloadCoordinator | null = null;
  private switchDepth: number = 0;
  /** loadCurrentSongStream 已对账后，跳过 onPipelinePhase(playing) 的重复 reconcile。 */
  private streamMetadataAligned: boolean = false;

  private readonly pipelineCallbacks: PipelineOrchestratorCallbacks = new SessionPipelineCallbacks(this);

  private beginSwitch(): void {
    this.switchDepth++;
  }

  private endSwitch(): void {
    if (this.switchDepth > 0) {
      this.switchDepth--;
    }
  }

  private isSwitching(): boolean {
    return this.switchDepth > 0;
  }

  private static cloneSongs(songs: Song[]): Song[] {
    const cloned: Song[] = [];
    for (let i: number = 0; i < songs.length; i++) {
      const item: Song = songs[i];
      cloned.push({
        id: item.id,
        parent: item.parent,
        isDir: item.isDir,
        title: item.title,
        album: item.album,
        artist: item.artist,
        track: item.track,
        year: item.year,
        genre: item.genre,
        coverArt: item.coverArt,
        albumId: item.albumId,
        size: item.size,
        contentType: item.contentType,
        suffix: item.suffix,
        duration: item.duration,
        bitRate: item.bitRate,
        path: item.path,
        playCount: item.playCount,
        created: item.created,
        starred: item.starred
      });
    }
    return cloned;
  }

  static getInstance(): PlaybackSession {
    if (PlaybackSession.instance === null) {
      PlaybackSession.instance = new PlaybackSession();
    }
    return PlaybackSession.instance;
  }

  setTransportHandler(handler: SystemTransportHandler): void {
    this.transportHandler = handler;
  }

  getTransportHandler(): SystemTransportHandler | null {
    return this.transportHandler;
  }

  getCurrentMode(): PlaybackMode {
    return this.currentMode;
  }

  async ensureInitialized(): Promise<void> {
    if (this.initialized) {
      return;
    }
    if (this.context === null) {
      return;
    }
    await this.initialize(this.context);
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.initialized) {
      PlaybackStore.setSessionReady(true);
      return;
    }
    if (this.initPromise !== null) {
      await this.initPromise;
      return;
    }
    PlaybackStore.setSessionReady(false);
    this.initPromise = this.runFirstTimeInitialize(context);
    try {
      await this.initPromise;
    } catch (err) {
      this.initPromise = null;
      throw err as Error;
    }
  }

  private async runFirstTimeInitialize(context: common.UIAbilityContext): Promise<void> {
    CoverCache.setContext(context);
    CoverCacheStore.ensureInitialized();
    SongCacheStore.ensureInitialized();
    SongCache.setContext(context);
    await Promise.all([
      SongCache.init(),
      CoverCache.init()
    ]);
    BackgroundPlayback.setContext(context);
    this.mediaCenter.setContext(context);
    this.mediaCenter.setCommands(new SessionMediaCenterCommands(this));
    this.orchestrator.setContext(context);
    this.orchestrator.setCallbacks(this.pipelineCallbacks);
    if (this.initialized) {
      PlaybackStore.setSessionReady(true);
      return;
    }
    PlaybackStore.init(PlaybackSession.buildInitialPlaybackSnapshot(this.stagedPlayPreview));
    PlaylistStore.init(PlaylistSnapshot.empty());
    await PlaylistPersistence.getInstance().init(context);
    await this.orchestrator.initialize();
    await PreloadDeviceCapability.probe();
    this.preloadCoordinator = new NextTrackPreloadCoordinator(this.buildPreloadDeps());
    this.orchestrator.setStandbyPrepareFailedCallback((songId: string): void => {
      this.preloadCoordinator?.handleStandbyPrepareFailed(songId);
    });
    await this.restorePersistedPlaylist();
    PlaybackPipeline.setNetworkPathChangedHandler((event: EndpointChangeEvent) => {
      return this.handleNetworkPathChanged(event);
    });
    this.initialized = true;
    PlaybackStore.setSessionReady(true);
    this.initPromise = null;
  }

  setContext(context: common.UIAbilityContext): void {
    void this.initialize(context);
  }

  async flushPersistence(): Promise<void> {
    await PlaylistPersistence.getInstance().flushPending();
  }

  async release(): Promise<void> {
    this.stopHeartbeat();
    this.systemCommandInFlight = false;
    this.preloadCoordinator?.reset();
    await this.submitCurrentTrackCompletion('release');
    await this.orchestrator.release();
    await BackgroundPlayback.release();
    await this.mediaCenter.release();
    await CoverCache.releaseAll();
    this.releaseActiveStream();
    this.releaseCover();
    this.displayQueue = [];
    this.currentIndex = -1;
    this.cachedPublishedItems = [];
    this.shuffleOrder = [];
    this.shuffleCursor = 0;
    this.previewTrack = null;
    this.stagedPlayPreview = null;
    this.isBuffering = false;
    this.initialized = false;
    this.initPromise = null;
    PlaybackStore.setSessionReady(false);
    this.snapshot = PlaybackSnapshot.idle();
    PlaybackStore.publish(this.snapshot);
    this.publishPlaylist(true);
    void PlaylistPersistence.getInstance().clear();
  }

  setPlaybackMode(mode: PlaybackMode): PlaybackMode {
    if (this.currentMode === mode) {
      return this.currentMode;
    }
    this.applyModeChange(mode);
    return this.currentMode;
  }

  togglePlaybackMode(): PlaybackMode {
    let nextMode: PlaybackMode = 'listLoop';
    if (this.currentMode === 'listLoop') {
      nextMode = 'singleLoop';
    } else if (this.currentMode === 'singleLoop') {
      nextMode = 'random';
    }
    this.applyModeChange(nextMode);
    return this.currentMode;
  }

  private applyModeChange(nextMode: PlaybackMode): void {
    if (this.currentMode === 'random' && nextMode !== 'random') {
      this.shuffleOrder = [];
      this.shuffleCursor = 0;
    }
    if (nextMode === 'random' && this.currentMode !== 'random' &&
      this.currentIndex >= 0 && this.displayQueue.length > 0) {
      this.shuffleOrder = ShuffleController.buildShuffleOrder(this.displayQueue.length, this.currentIndex);
      this.shuffleCursor = 0;
    }
    this.currentMode = nextMode;
    this.publishSnapshot(this.snapshot.phase, true);
  }

  private publishPlaylist(structureChanged: boolean = true): void {
    this.playlistRevision += 1;
    if (structureChanged) {
      this.cachedPublishedItems = this.displayQueue.map((item: Song) => item);
    }
    PlaylistStore.publish(new PlaylistSnapshot(
      this.cachedPublishedItems,
      this.currentIndex,
      this.playlistRevision
    ));
    PlaylistPersistence.getInstance().scheduleSave(this.displayQueue, this.currentIndex);
  }

  private hasActivePlaybackSession(): boolean {
    return this.activeStreamResource !== null ||
      this.previewTrack !== null ||
      this.pipelinePhase !== 'idle';
  }

  private async restorePersistedPlaylist(): Promise<void> {
    const restored = await PlaylistPersistence.getInstance().load();
    if (restored === null || restored.songs.length === 0) {
      return;
    }
    if (this.hasActivePlaybackSession()) {
      await this.reconcilePlaybackMetadata(true);
      return;
    }
    this.displayQueue = PlaybackSession.cloneSongs(restored.songs);
    this.currentIndex = restored.currentIndex;
    this.cachedPublishedItems = this.displayQueue.map((item: Song) => item);
    this.playlistRevision += 1;
    PlaylistStore.publish(new PlaylistSnapshot(
      this.cachedPublishedItems,
      this.currentIndex,
      this.playlistRevision
    ));
    this.publishSnapshot('idle', true);
  }

  /** 流已开播但队列游标/快照仍指向旧曲时，按 activeStreamResource.songId 对齐元数据。 */
  private async reconcilePlaybackMetadata(forcePublish: boolean): Promise<void> {
    const resource: StreamResource | null = this.activeStreamResource;
    if (resource === null) {
      return;
    }
    const streamSongId: string = resource.songId;
    if (streamSongId.length === 0) {
      return;
    }
    const snapshotTrackId: string = this.snapshot.track !== null ? this.snapshot.track.id : '';
    const currentSong: Song | null = this.getCurrentSong();
    const queueMatches: boolean = currentSong !== null && currentSong.id === streamSongId;
    if (snapshotTrackId === streamSongId && queueMatches) {
      this.streamMetadataAligned = true;
      return;
    }
    let foundIndex: number = -1;
    for (let i: number = 0; i < this.displayQueue.length; i++) {
      if (this.displayQueue[i].id === streamSongId) {
        foundIndex = i;
        break;
      }
    }
    if (foundIndex >= 0) {
      this.currentIndex = foundIndex;
    } else {
      try {
        const fetched: Song = await SubsonicClient.getInstance().getSong(streamSongId);
        this.displayQueue = [fetched, ...this.displayQueue];
        this.currentIndex = 0;
        if (fetched.coverArt !== undefined && fetched.coverArt.length > 0) {
          this.albumCoverFallbackId = fetched.coverArt;
        }
        this.publishPlaylist(true);
      } catch (err) {
        Logger.warn('PlaybackSession', `reconcile getSong failed: ${(err as Error).message}`);
        return;
      }
    }
    this.streamMetadataAligned = true;
    if (forcePublish) {
      this.publishSnapshot(this.pipelinePhase, true);
    }
  }

  private static buildInitialPlaybackSnapshot(stagedPreview: NowPlayingTrack | null): PlaybackSnapshot {
    if (stagedPreview !== null) {
      return new PlaybackSnapshot(stagedPreview, 'loading', 0, 'listLoop', true, 0, false);
    }
    return PlaybackSnapshot.idle();
  }

  /** 点播后立即写入全局 playback 快照，miniBar 封面进入 loading（无需等 init 结束）。 */
  private publishStagedPlayPreview(track: NowPlayingTrack, albumCoverArtId?: string): void {
    this.stagedPlayPreview = track;
    if (albumCoverArtId !== undefined && albumCoverArtId.length > 0) {
      this.albumCoverFallbackId = albumCoverArtId;
    }
    PlaybackStore.publish(new PlaybackSnapshot(
      track,
      'loading',
      0,
      this.currentMode,
      true,
      this.coverRevision,
      false
    ));
  }

  async playQueue(songs: Song[], index: number, albumCoverArtId?: string): Promise<void> {
    if (songs.length === 0) {
      return;
    }
    const safeIndex: number = index >= 0 && index < songs.length ? index : 0;
    const previewTrack: NowPlayingTrack = buildNowPlayingTrack(songs[safeIndex], albumCoverArtId ?? '');
    this.publishStagedPlayPreview(previewTrack, albumCoverArtId);
    await this.ensureInitialized();
    this.beginSwitch();
    try {
      this.albumCoverFallbackId = albumCoverArtId ?? '';
      this.displayQueue = PlaybackSession.cloneSongs(songs);
      this.currentIndex = safeIndex;
      this.shuffleOrder = [];
      this.shuffleCursor = 0;
      const targetSong: Song = this.displayQueue[safeIndex];
      const previewTrack: NowPlayingTrack = buildNowPlayingTrack(targetSong, this.albumCoverFallbackId);
      await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
      await PlaybackSwitch.commitSwitch(this, true);
      this.publishPlaylist(true);
    } finally {
      this.endSwitch();
    }
  }

  async playAlbumAll(album: Album): Promise<void> {
    const previewTrack: NowPlayingTrack = this.buildPreviewTrackFromAlbum(album);
    this.publishStagedPlayPreview(previewTrack, album.coverArt);
    await this.ensureInitialized();
    await PlaybackSwitch.prepareSwitchFromAlbum(this, album);
    try {
      const resp = await SubsonicClient.getInstance().getAlbum(album.id);
      const songs: Song[] = resp.album.song ?? [];
      if (songs.length === 0) {
        throw new Error('EMPTY_ALBUM');
      }
      const coverArt: string = album.coverArt ?? resp.album.coverArt ?? '';
      await this.playQueue(songs, 0, coverArt);
    } catch (err) {
      PlaybackSwitch.restoreFailedSwitch(this);
      throw err as Error;
    }
  }

  async enqueueNext(song: Song): Promise<void> {
    await this.ensureInitialized();
    if (this.displayQueue.length === 0 || this.currentIndex < 0) {
      this.displayQueue = [song];
      this.currentIndex = 0;
      this.shuffleOrder = [];
      this.shuffleCursor = 0;
      this.albumCoverFallbackId = song.coverArt ?? this.albumCoverFallbackId;
      const previewTrack: NowPlayingTrack = buildNowPlayingTrack(song, this.albumCoverFallbackId);
      await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
      await PlaybackSwitch.commitSwitch(this, true);
      this.publishPlaylist(true);
      return;
    }
    const nextInsertIndex: number = this.currentIndex + 1;
    const before: Song[] = this.displayQueue.slice(0, nextInsertIndex);
    const after: Song[] = this.displayQueue.slice(nextInsertIndex);
    this.displayQueue = [...before, song, ...after];
    if (this.currentMode === 'random' && this.shuffleOrder.length > 0) {
      this.shuffleOrder = ShuffleController.remapAfterInsert(
        this.shuffleOrder,
        nextInsertIndex,
        this.shuffleCursor
      );
    }
    this.publishPlaylist(true);
  }

  async appendToPlaylist(songs: Song[]): Promise<number> {
    if (songs.length === 0) {
      return 0;
    }
    const existingIds: Set<string> = new Set<string>();
    for (let i: number = 0; i < this.displayQueue.length; i++) {
      existingIds.add(this.displayQueue[i].id);
    }
    const toAdd: Song[] = [];
    for (let i: number = 0; i < songs.length; i++) {
      if (!existingIds.has(songs[i].id)) {
        toAdd.push(songs[i]);
        existingIds.add(songs[i].id);
      }
    }
    if (toAdd.length === 0) {
      return 0;
    }
    const startIndex: number = this.displayQueue.length;
    this.displayQueue = [...this.displayQueue, ...toAdd];
    if (this.currentMode === 'random' && this.shuffleOrder.length > 0) {
      for (let i: number = 0; i < toAdd.length; i++) {
        this.shuffleOrder.push(startIndex + i);
      }
    }
    this.publishPlaylist(true);
    return toAdd.length;
  }

  async appendAlbumToPlaylist(albumId: string): Promise<number> {
    const resp = await SubsonicClient.getInstance().getAlbum(albumId);
    const songs: Song[] = resp.album.song ?? [];
    return this.appendToPlaylist(songs);
  }

  async playFromPlaylistIndex(index: number): Promise<void> {
    await this.ensureInitialized();
    if (index < 0 || index >= this.displayQueue.length) {
      return;
    }
    this.beginSwitch();
    try {
      const targetSong: Song = this.displayQueue[index];
      const previewTrack: NowPlayingTrack = buildNowPlayingTrack(targetSong, this.albumCoverFallbackId);
      this.currentIndex = index;
      await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
      if (this.currentMode === 'random') {
        const cursor: number = ShuffleController.findCursorForIndex(this.shuffleOrder, index);
        if (cursor >= 0) {
          this.shuffleCursor = cursor;
        } else {
          this.shuffleOrder = ShuffleController.buildShuffleOrder(this.displayQueue.length, index);
          this.shuffleCursor = 0;
        }
      }
      await PlaybackSwitch.commitSwitch(this, true);
      this.publishPlaylist(false);
    } finally {
      this.endSwitch();
    }
  }

  async removeFromPlaylist(index: number): Promise<void> {
    if (index < 0 || index >= this.displayQueue.length) {
      return;
    }
    const removingCurrent: boolean = index === this.currentIndex;
    this.displayQueue = [
      ...this.displayQueue.slice(0, index),
      ...this.displayQueue.slice(index + 1)
    ];
    if (this.currentIndex > index) {
      this.currentIndex -= 1;
    } else if (removingCurrent) {
      if (this.displayQueue.length === 0) {
        this.currentIndex = -1;
        await this.stopEngineAndClearBuffers();
        this.clearPreview();
        this.pipelinePhase = 'idle';
        this.publishSnapshot('idle', true);
        this.publishPlaylist(true);
        await BackgroundPlayback.stop();
        PlaybackPipeline.onTrackStopped();
      } else if (this.currentIndex >= this.displayQueue.length) {
        this.currentIndex = this.displayQueue.length - 1;
        await this.playFromPlaylistIndex(this.currentIndex);
        return;
      }
    }
    if (this.currentMode === 'random' && this.shuffleOrder.length > 0) {
      this.shuffleOrder = ShuffleController.remapAfterRemove(this.shuffleOrder, index);
      if (this.shuffleCursor >= this.shuffleOrder.length) {
        this.shuffleCursor = Math.max(0, this.shuffleOrder.length - 1);
      }
      const cursor: number = ShuffleController.findCursorForIndex(this.shuffleOrder, this.currentIndex);
      if (cursor >= 0) {
        this.shuffleCursor = cursor;
      }
    }
    this.publishPlaylist(true);
  }

  async toggle(): Promise<void> {
    await this.ensureInitialized();
    const sinkPhase: PlaySinkPhase = this.orchestrator.getPhase();
    if (this.pipelinePhase === 'playing' || sinkPhase === 'playing') {
      await this.orchestrator.pause();
      this.pipelinePhase = 'paused';
      this.isBuffering = false;
      this.publishSnapshot('paused', true);
      return;
    }
    if (this.getCurrentSong() === null && this.displayQueue.length > 0) {
      await PlaybackSwitch.commitSwitch(this, true);
      return;
    }
    if (sinkPhase === 'error' || sinkPhase === 'loading' ||
      (this.pipelinePhase === 'loading' && this.getCurrentSong() !== null)) {
      await this.orchestrator.resumeAfterError();
      return;
    }
    const resumingFromPause: boolean = this.pipelinePhase === 'paused' || sinkPhase === 'paused';
    if (resumingFromPause) {
      this.pipelinePhase = 'loading';
      this.publishSnapshot('loading', true);
    }
    await this.orchestrator.play();
    const song: Song | null = this.getCurrentSong();
    if (song !== null) {
      try {
        await SubsonicClient.getInstance().reportNowPlaying(song.id, this.orchestrator.getPositionMs());
      } catch (err) {
        Logger.warn('PlaybackSession', `resume nowPlaying failed: ${this.classifyScrobbleError(err as Error)}`);
      }
    }
  }

  async playNext(manual: boolean = true): Promise<void> {
    await this.ensureInitialized();
    if (this.displayQueue.length === 0) {
      return;
    }
    this.beginSwitch();
    try {
      const nav = resolveNextPlayback(
        this.displayQueue.length,
        this.currentIndex,
        this.currentMode,
        manual,
        this.shuffleOrder,
        this.shuffleCursor
      );
      if (nav.reshuffleOrder !== null) {
        this.shuffleOrder = nav.reshuffleOrder;
      }
      this.shuffleCursor = nav.shuffleCursor;
      const nextSong: Song = this.displayQueue[nav.index];
      const previewTrack: NowPlayingTrack = buildNowPlayingTrack(nextSong, this.albumCoverFallbackId);
      this.currentIndex = nav.index;
      await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
      await PlaybackSwitch.commitSwitch(this, true);
      this.publishPlaylist(false);
    } finally {
      this.endSwitch();
    }
  }

  async playPrevious(): Promise<void> {
    await this.ensureInitialized();
    if (this.displayQueue.length === 0) {
      return;
    }
    this.beginSwitch();
    try {
      const nav = resolvePreviousPlayback(
        this.displayQueue.length,
        this.currentIndex,
        this.currentMode,
        this.shuffleOrder,
        this.shuffleCursor
      );
      this.shuffleCursor = nav.shuffleCursor;
      const prevSong: Song = this.displayQueue[nav.index];
      const previewTrack: NowPlayingTrack = buildNowPlayingTrack(prevSong, this.albumCoverFallbackId);
      this.currentIndex = nav.index;
      await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
      await PlaybackSwitch.commitSwitch(this, true);
      this.publishPlaylist(false);
    } finally {
      this.endSwitch();
    }
  }

  async seekTo(positionMs: number): Promise<void> {
    const track: NowPlayingTrack | null = this.snapshot.track;
    if (track === null) {
      return;
    }
    let maxDurationMs: number = track.durationMs;
    if (maxDurationMs <= 0) {
      maxDurationMs = this.orchestrator.getDurationMs();
    }
    let safe: number = positionMs;
    if (safe < 0) {
      safe = 0;
    }
    if (maxDurationMs > 0 && safe > maxDurationMs) {
      safe = maxDurationMs;
    }
    await this.orchestrator.seek(safe);
    this.frozenPositionMs = safe;
    this.publishSnapshot(this.pipelinePhase, true);
    this.evaluateNextPreload();
  }

  buildPreviewTrackFromAlbum(album: Album): NowPlayingTrack {
    const albumTitle: string = album.title ?? album.name ?? '未知专辑';
    return new NowPlayingTrack(
      album.id,
      albumTitle,
      album.artist.length > 0 ? album.artist : '未知歌手',
      albumTitle,
      album.coverArt ?? '',
      0
    );
  }

  lockPreview(track: NowPlayingTrack, albumCoverArtId?: string): void {
    this.stagedPlayPreview = null;
    if (albumCoverArtId !== undefined && albumCoverArtId.length > 0) {
      this.albumCoverFallbackId = albumCoverArtId;
    }
    this.previewTrack = track;
    this.isBuffering = false;
    this.coverRevision += 1;
    this.publishSnapshot('loading', true);
    if (track.coverArtId.length > 0) {
      void this.ensureCover(track.coverArtId);
    }
  }

  clearPreview(): void {
    this.previewTrack = null;
  }

  restoreSnapshotFromEngine(): void {
    this.restoreSnapshotFromPipeline();
  }

  restoreSnapshotFromPipeline(): void {
    const sinkPhase: PlaySinkPhase = this.orchestrator.getPhase();
    this.pipelinePhase = PlaybackSession.mapSinkPhase(sinkPhase);
    this.isBuffering = this.orchestrator.isBuffering();
    this.publishSnapshot(this.pipelinePhase, true);
  }

  async submitCurrentTrackCompletionOnSwitch(): Promise<void> {
    await this.submitCurrentTrackCompletion('switch');
  }

  async stopEngineAndClearBuffers(): Promise<void> {
    const song: Song | null = this.getCurrentSong();
    if (song !== null) {
      SongCache.cancelActiveDownload(song.id);
    }
    SongCache.unpin();
    await this.orchestrator.cancel();
    this.releaseActiveStream();
    this.isBuffering = false;
  }

  private releaseActiveStream(): void {
    if (this.activeStreamResource !== null) {
      this.activeStreamResource.cancelToken.cancel();
      this.activeStreamResource = null;
    }
    this.streamMetadataAligned = false;
  }

  async loadCurrentSongStream(reportStart: boolean): Promise<void> {
    const song: Song | null = this.getCurrentSong();
    if (song === null) {
      SongCache.unpin();
      await this.orchestrator.cancel();
      this.releaseCover();
      this.currentIndex = -1;
      this.clearPreview();
      this.isBuffering = false;
      this.pipelinePhase = 'idle';
      this.publishSnapshot('idle', true);
      this.publishPlaylist(true);
      await BackgroundPlayback.stop();
      PlaybackPipeline.onTrackStopped();
      return;
    }
    this.clearPreview();
    this.isBuffering = false;
    this.frozenPositionMs = 0;
    const track: NowPlayingTrack = buildNowPlayingTrack(song, this.albumCoverFallbackId);
    this.pipelinePhase = 'loading';
    this.publishSnapshot('loading', true);
    this.releaseActiveStream();
    this.activeStreamResource = MediaResourceService.openStream(song.id);
    PlaybackPipeline.onTrackStarted(song.id);
    const durationMs: number = track.durationMs;
    const coverTask: Promise<image.PixelMap | null> = this.ensureCover(track.coverArtId);
    try {
      await this.orchestrator.startTrack(this.activeStreamResource, durationMs, true);
    } catch (err) {
      this.publishSnapshot('error', true);
      Logger.error('PlaybackSession', `play failed: ${(err as Error).message}`);
      return;
    }
    await this.afterTrackEngineStarted(song, reportStart, coverTask, false);
  }

  getSwitchTargetSongId(): string {
    const song: Song | null = this.getCurrentSong();
    return song !== null ? song.id : '';
  }

  resetNextTrackPreload(): void {
    this.preloadCoordinator?.reset();
  }

  async tryPromoteStandbyForSwitch(nextSongId: string): Promise<boolean> {
    if (nextSongId.length === 0) {
      return false;
    }
    if (SongCache.resolveLocalPath(nextSongId) !== null) {
      await this.orchestrator.cancelStandby();
      return false;
    }
    if (!this.orchestrator.isStandbyReady(nextSongId)) {
      return false;
    }
    return await this.orchestrator.promoteStandbyToActive(true);
  }

  async finishPromotedSwitch(reportStart: boolean): Promise<void> {
    const song: Song | null = this.getCurrentSong();
    if (song === null) {
      return;
    }
    this.clearPreview();
    this.isBuffering = false;
    this.frozenPositionMs = 0;
    this.activeStreamResource = this.orchestrator.getActiveStreamResource();
    this.pipelinePhase = 'playing';
    this.publishSnapshot('playing', true);
    PlaybackPipeline.onTrackStarted(song.id);
    const track: NowPlayingTrack = buildNowPlayingTrack(song, this.albumCoverFallbackId);
    const coverTask: Promise<image.PixelMap | null> = this.ensureCover(track.coverArtId);
    await this.afterTrackEngineStarted(song, reportStart, coverTask, true);
  }

  /** 引擎已开播后的公共收尾：pin / 边听边下 / 封面 / 元数据 / 可选 heartbeat */
  private async afterTrackEngineStarted(
    song: Song,
    reportStart: boolean,
    coverTask: Promise<image.PixelMap | null>,
    startHeartbeatAfter: boolean
  ): Promise<void> {
    if (reportStart) {
      try {
        await SubsonicClient.getInstance().reportNowPlaying(song.id, 0);
      } catch (err) {
        Logger.warn('PlaybackSession', `nowPlaying failed: ${this.classifyScrobbleError(err as Error)}`);
      }
    }
    SongCache.pin(song.id);
    if (SongCache.shouldAutoCacheNow() && !SongCache.isComplete(song.id)) {
      void SongCache.enqueueDownload(song.id);
    }
    await coverTask;
    await this.reconcilePlaybackMetadata(true);
    if (startHeartbeatAfter) {
      this.startHeartbeat();
    }
  }

  private async handleNetworkPathChanged(event: EndpointChangeEvent): Promise<void> {
    const song: Song | null = this.getCurrentSong();
    if (song === null || this.activeStreamResource === null) {
      return;
    }
    const phase: PlaybackPhase = this.snapshot.phase;
    if (phase !== 'playing' && phase !== 'paused' && phase !== 'loading') {
      return;
    }
    await this.orchestrator.onNetworkPathChanged(event);
    this.preloadCoordinator?.onEndpointChanged();
  }

  getAuthoritativePositionMs(): number {
    if (this.isBuffering) {
      return this.frozenPositionMs;
    }
    return this.orchestrator.getPositionMs();
  }

  onPipelineEnterBuffering(frozenPositionMs: number): void {
    this.isBuffering = true;
    this.frozenPositionMs = frozenPositionMs;
    if (this.pipelinePhase === 'playing' || this.snapshot.phase === 'playing') {
      this.pipelinePhase = 'paused';
      this.stopHeartbeat();
    }
    this.publishSnapshot(this.pipelinePhase, true);
  }

  onPipelineExitBuffering(): void {
    this.isBuffering = false;
    this.publishSnapshot(this.pipelinePhase, true);
    void this.syncMediaCenter(this.snapshot, true);
  }

  handlePipelineError(message: string): void {
    Logger.warn('PlaybackSession', message);
    if (this.getCurrentSong() !== null &&
      (this.pipelinePhase === 'playing' || this.pipelinePhase === 'paused' || this.isBuffering)) {
      this.isBuffering = true;
      if (this.pipelinePhase === 'playing') {
        this.pipelinePhase = 'paused';
        this.stopHeartbeat();
      }
      this.publishSnapshot(this.pipelinePhase, true);
      void this.syncMediaCenter(this.snapshot, true);
      return;
    }
    this.isBuffering = false;
    this.publishSnapshot('error');
  }

  onPipelinePhase(phase: PlaySinkPhase): void {
    if (phase === 'error') {
      this.handlePipelineError('player error');
      return;
    }
    if (this.isBuffering && (this.pipelinePhase === 'playing' || phase === 'loading' ||
      phase === 'stopped' || phase === 'idle')) {
      return;
    }
    if (this.pipelinePhase === 'playing' && phase === 'loading') {
      return;
    }
    let mappedPhase: PlaybackPhase = PlaybackSession.mapSinkPhase(phase);
    // 当队列有曲目时，不让状态掉到 idle — 防止 miniBar 状态丢失和后台任务被停止
    if (mappedPhase === 'idle' && this.displayQueue.length > 0 && this.currentIndex >= 0) {
      mappedPhase = 'paused';
    }
    this.pipelinePhase = mappedPhase;
    if (this.pipelinePhase === 'playing') {
      this.startHeartbeat();
      if (this.streamMetadataAligned) {
        this.streamMetadataAligned = false;
        this.publishSnapshot(this.pipelinePhase, true);
        void this.syncMediaCenter(this.snapshot, true);
        const alignedTrack: NowPlayingTrack | null = this.snapshot.track;
        if (alignedTrack === null) {
          void BackgroundPlayback.stop();
        } else {
          void BackgroundPlayback.start(alignedTrack.title, alignedTrack.artist, true);
        }
        return;
      }
      void this.reconcilePlaybackMetadata(true).then(() => {
        void this.syncMediaCenter(this.snapshot, true);
        const track: NowPlayingTrack | null = this.snapshot.track;
        if (track === null) {
          void BackgroundPlayback.stop();
          return;
        }
        void BackgroundPlayback.start(track.title, track.artist, true);
      });
      return;
    }
    if (this.pipelinePhase === 'paused' || this.pipelinePhase === 'error' ||
      this.pipelinePhase === 'idle') {
      this.stopHeartbeat();
    }
    this.publishSnapshot(this.pipelinePhase, true);
    void this.syncMediaCenter(this.snapshot, true);
    const track: NowPlayingTrack | null = this.snapshot.track;
    if (track === null) {
      // 只在队列为空时才停止后台任务，防止切歌窗口期后台任务被意外停止
      if (this.displayQueue.length === 0) {
        void BackgroundPlayback.stop();
      }
      return;
    }
    if (this.pipelinePhase === 'paused' || this.pipelinePhase === 'idle' || this.pipelinePhase === 'error') {
      void BackgroundPlayback.update(track.title, track.artist, false);
    }
  }

  onPipelinePosition(_positionMs: number): void {
    if (this.previewTrack !== null || this.isBuffering) {
      return;
    }
    const now: number = Date.now();
    if (now - this.lastMediaCenterPositionAt < UI_POSITION_PUBLISH_INTERVAL_MS) {
      return;
    }
    this.lastMediaCenterPositionAt = now;
    this.publishSnapshot(this.pipelinePhase, false);
    void this.mediaCenter.syncPlaybackState(this.snapshot);
    this.evaluateNextPreload();
  }

  onPipelineDuration(durationMs: number): void {
    const baseTrack: NowPlayingTrack | null = this.resolveActiveNowPlayingTrack();
    if (baseTrack === null) {
      return;
    }
    const updated: NowPlayingTrack = new NowPlayingTrack(
      baseTrack.id,
      baseTrack.title,
      baseTrack.artist,
      baseTrack.album,
      baseTrack.coverArtId,
      durationMs > 0 ? durationMs : baseTrack.durationMs
    );
    const showMiniPlayer: boolean = this.previewTrack !== null || this.getCurrentSong() !== null;
    this.snapshot = new PlaybackSnapshot(
      updated,
      this.snapshot.phase,
      this.snapshot.positionMs,
      this.currentMode,
      showMiniPlayer,
      this.coverRevision,
      this.isBuffering
    );
    PlaybackStore.publish(this.snapshot);
    if (durationMs > 0) {
      void this.syncMediaCenter(this.snapshot, true);
      this.evaluateNextPreload();
    }
  }

  private static shouldExposeQueueTrack(phase: PlaybackPhase): boolean {
    return phase === 'loading' || phase === 'playing' || phase === 'paused' || phase === 'error';
  }

  /** 从 preview 或队列当前曲构建元数据；idle 时不暴露队列游标曲目。 */
  private resolveActiveNowPlayingTrack(exposePhase?: PlaybackPhase): NowPlayingTrack | null {
    if (this.previewTrack !== null) {
      return this.previewTrack;
    }
    const phaseForExpose: PlaybackPhase = exposePhase ?? this.pipelinePhase;
    if (!PlaybackSession.shouldExposeQueueTrack(phaseForExpose)) {
      return null;
    }
    const song: Song | null = this.getCurrentSong();
    if (song === null) {
      return null;
    }
    let track: NowPlayingTrack = buildNowPlayingTrack(song, this.albumCoverFallbackId);
    const durationMs: number = this.orchestrator.getDurationMs();
    if (durationMs > 0) {
      track = new NowPlayingTrack(
        track.id,
        track.title,
        track.artist,
        track.album,
        track.coverArtId,
        durationMs
      );
    }
    return track;
  }

  private static mapSinkPhase(phase: PlaySinkPhase): PlaybackPhase {
    if (phase === 'loading') {
      return 'loading';
    }
    if (phase === 'playing') {
      return 'playing';
    }
    if (phase === 'paused') {
      return 'paused';
    }
    if (phase === 'error') {
      return 'error';
    }
    return 'idle';
  }

  private publishSnapshot(phase: PlaybackPhase, forceMedia: boolean = false): void {
    let track: NowPlayingTrack | null = null;
    let positionMs: number = 0;
    let showMiniPlayer: boolean = false;
    let snapshotPhase: PlaybackPhase = phase;

    if (this.previewTrack !== null) {
      track = this.previewTrack;
      snapshotPhase = 'loading';
      positionMs = 0;
      showMiniPlayer = true;
    } else if (PlaybackSession.shouldExposeQueueTrack(phase)) {
      const resolvedTrack: NowPlayingTrack | null = this.resolveActiveNowPlayingTrack(phase);
      if (resolvedTrack !== null) {
        track = resolvedTrack;
        showMiniPlayer = true;
      }
      if (this.isBuffering) {
        positionMs = this.frozenPositionMs;
      } else {
        positionMs = this.orchestrator.getPositionMs();
      }
    }

    this.snapshot = new PlaybackSnapshot(
      track,
      snapshotPhase,
      positionMs,
      this.currentMode,
      showMiniPlayer,
      this.coverRevision,
      this.isBuffering
    );
    PlaybackStore.publish(this.snapshot);
    if (forceMedia) {
      void this.syncMediaCenter(this.snapshot, true);
    }
  }

  private async syncMediaCenter(snapshot: PlaybackSnapshot, force: boolean): Promise<void> {
    let cover: image.PixelMap | null = null;
    if (snapshot.track !== null && snapshot.track.coverArtId.length > 0) {
      CoverCache.pin(snapshot.track.coverArtId);
      cover = CoverCache.getDisplaySource(snapshot.track.coverArtId).pixelMap;
      if (cover === null) {
        cover = await CoverCache.load(snapshot.track.coverArtId);
        if (cover !== null) {
          this.coverRevision = CoverCache.getRevision();
        }
      }
      this.currentCover = cover;
      this.currentCoverId = snapshot.track.coverArtId;
    } else {
      this.releaseCover();
    }
    await this.mediaCenter.apply(snapshot, cover);
  }

  private async ensureCover(coverArtId: string): Promise<image.PixelMap | null> {
    if (coverArtId.length === 0) {
      return null;
    }
    const existing: image.PixelMap | null = CoverCache.getDisplaySource(coverArtId).pixelMap;
    if (existing !== null) {
      this.coverRevision = CoverCache.getRevision();
      return existing;
    }
    const loaded: image.PixelMap | null = await CoverCache.load(coverArtId);
    if (loaded !== null) {
      this.coverRevision = CoverCache.getRevision();
      this.publishSnapshot(this.snapshot.phase, true);
    }
    return loaded;
  }

  private releaseCover(): void {
    CoverCache.unpin();
    this.currentCover = null;
    this.currentCoverId = '';
  }

  async handleSystemPlay(): Promise<void> {
    await this.ensureInitialized();
    if (this.systemCommandInFlight) {
      return;
    }
    this.systemCommandInFlight = true;
    try {
      const sinkPhase: PlaySinkPhase = this.orchestrator.getPhase();
      if (sinkPhase === 'playing') {
        return;
      }
      if (this.getCurrentSong() === null && this.displayQueue.length > 0) {
        await PlaybackSwitch.commitSwitch(this, true);
        return;
      }
      if (sinkPhase === 'error' || sinkPhase === 'loading' ||
        (this.pipelinePhase === 'loading' && this.getCurrentSong() !== null)) {
        await this.orchestrator.resumeAfterError();
        return;
      }
      await this.orchestrator.play();
    } finally {
      this.systemCommandInFlight = false;
    }
  }

  async handleSystemPause(): Promise<void> {
    if (this.systemCommandInFlight) {
      return;
    }
    this.systemCommandInFlight = true;
    try {
      if (this.orchestrator.getPhase() === 'playing') {
        await this.orchestrator.pause();
      }
    } finally {
      this.systemCommandInFlight = false;
    }
  }

  async handleTrackCompleted(): Promise<void> {
    if (this.handlingCompletion || this.isSwitching()) {
      return;
    }
    this.handlingCompletion = true;
    await this.submitCurrentTrackCompletion('completed');
    if (this.displayQueue.length === 0) {
      this.handlingCompletion = false;
      return;
    }
    if (this.currentMode === 'singleLoop') {
      const song: Song | null = this.getCurrentSong();
      if (song !== null) {
        const previewTrack: NowPlayingTrack = buildNowPlayingTrack(song, this.albumCoverFallbackId);
        await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
        await PlaybackSwitch.commitSwitch(this, true);
      }
      this.handlingCompletion = false;
      return;
    }
    const nav = resolveNextPlayback(
      this.displayQueue.length,
      this.currentIndex,
      this.currentMode,
      false,
      this.shuffleOrder,
      this.shuffleCursor
    );
    if (nav.reshuffleOrder !== null) {
      this.shuffleOrder = nav.reshuffleOrder;
    }
    this.shuffleCursor = nav.shuffleCursor;
    const nextSong: Song = this.displayQueue[nav.index];
    const previewTrack: NowPlayingTrack = buildNowPlayingTrack(nextSong, this.albumCoverFallbackId);
    await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
    this.currentIndex = nav.index;
    await PlaybackSwitch.commitSwitch(this, true);
    this.handlingCompletion = false;
    this.publishPlaylist(true);
  }

  private buildPreloadDeps(): PreloadDeps {
    return {
      orchestrator: this.orchestrator,
      openStream: (songId: string): StreamResource => MediaResourceService.openStream(songId),
      enqueueDownload: (songId: string): void => {
        void SongCache.enqueueDownload(songId);
      },
      isComplete: (songId: string): boolean => SongCache.isComplete(songId),
      shouldAutoCacheNow: (): boolean => SongCache.shouldAutoCacheNow(),
      isStandbyCapable: (): boolean => PreloadDeviceCapability.isStandbyCapable(),
      onStandbyPrepareFailed: (songId: string): void => {
        this.preloadCoordinator?.handleStandbyPrepareFailed(songId);
      }
    };
  }

  private buildPreloadContext(): PreloadContext | null {
    if (this.displayQueue.length === 0 || this.currentIndex < 0) {
      return null;
    }
    const currentSong: Song | null = this.getCurrentSong();
    if (currentSong === null) {
      return null;
    }
    const nav = resolveNextPlayback(
      this.displayQueue.length,
      this.currentIndex,
      this.currentMode,
      false,
      this.shuffleOrder,
      this.shuffleCursor
    );
    const nextSong: Song = this.displayQueue[nav.index];
    const snapshotDurationMs: number = this.snapshot.track !== null ? this.snapshot.track.durationMs : 0;
    const timing = resolvePreloadRemainingMs(
      this.getAuthoritativePositionMs(),
      this.orchestrator.getDurationMs(),
      snapshotDurationMs,
      currentSong.duration
    );
    return {
      currentSongId: currentSong.id,
      nextSong: nextSong,
      remainingMs: timing.remainingMs,
      durationMs: timing.durationMs,
      phase: this.pipelinePhase,
      endpoint: EndpointRouter.getActiveEndpoint()
    };
  }

  private evaluateNextPreload(): void {
    if (this.preloadCoordinator === null) {
      return;
    }
    const ctx: PreloadContext | null = this.buildPreloadContext();
    if (ctx === null) {
      return;
    }
    this.preloadCoordinator.onProgressTick(ctx);
  }

  private getCurrentSong(): Song | null {
    if (this.currentIndex < 0 || this.currentIndex >= this.displayQueue.length) {
      return null;
    }
    return this.displayQueue[this.currentIndex];
  }

  stopHeartbeat(): void {
    if (this.heartbeatTimerId >= 0) {
      clearInterval(this.heartbeatTimerId);
      this.heartbeatTimerId = -1;
    }
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatTimerId = setInterval(() => {
      void this.reportHeartbeat();
    }, HEARTBEAT_INTERVAL_MS);
  }

  private async reportHeartbeat(): Promise<void> {
    const song: Song | null = this.getCurrentSong();
    if (song === null || this.snapshot.phase !== 'playing') {
      return;
    }
    try {
      await SubsonicClient.getInstance().reportNowPlaying(song.id, this.getAuthoritativePositionMs());
    } catch (err) {
      Logger.warn('PlaybackSession', `heartbeat failed: ${this.classifyScrobbleError(err as Error)}`);
    }
  }

  private classifyScrobbleError(err: Error): string {
    if (err instanceof SubsonicApiError) {
      if (err.code === -3) {
        return 'auth';
      }
      if (err.code === 0) {
        return 'network';
      }
    }
    return 'unknown';
  }

  private async submitCurrentTrackCompletion(reason: string): Promise<void> {
    const song: Song | null = this.getCurrentSong();
    if (song === null) {
      return;
    }
    const durationMs: number = song.duration > 0 ? song.duration * 1000 : this.orchestrator.getDurationMs();
    let playedMs: number = this.getAuthoritativePositionMs();
    if (playedMs < 0) {
      playedMs = 0;
    }
    if (durationMs > 0 && playedMs > durationMs) {
      playedMs = durationMs;
    }
    if (durationMs > 0 && durationMs <= MIN_SCROBBLE_TRACK_LENGTH_MS) {
      return;
    }
    if (durationMs <= 0 && playedMs < MIN_SCROBBLE_TRACK_LENGTH_MS) {
      return;
    }
    const thresholdMs: number = durationMs > 0
      ? Math.min(Math.floor(durationMs / 2), MAX_SCROBBLE_PROGRESS_THRESHOLD_MS)
      : MIN_SCROBBLE_TRACK_LENGTH_MS;
    if (playedMs < thresholdMs) {
      return;
    }
    try {
      const playedAtMs: number = Date.now();
      await SubsonicClient.getInstance().submitScrobble(song.id, playedAtMs);
      SongMetadataCache.put(song);
      await RecentPlayHistoryStore.getInstance().recordPlay(song.id, playedAtMs);
      Logger.debug('PlaybackSession', `scrobble ok reason=${reason} id=${song.id}`);
    } catch (err) {
      Logger.warn('PlaybackSession', `scrobble failed: ${(err as Error).message}`);
    }
  }
}
