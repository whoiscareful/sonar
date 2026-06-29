import { common } from '@kit.AbilityKit';
import { AuthStore, EndpointType } from '../../auth/AuthStore';
import { AuthContext } from '../../network/auth/AuthContext';
import { SongCache } from '../../cache/SongCache';
import { Logger } from '../../common/Logger';
import { HttpTransport } from '../../network/transport/HttpTransport';
import { StreamResource } from '../../network/media/StreamResource';
import { EndpointChangeEvent } from '../../network/routing/EndpointTypes';
import { AudioRenderSink, AudioRenderSinkListener, PlaySinkPhase } from './AudioRenderSink';
import { PipelineMetrics } from './PipelineMetrics';
import { PlayerSlot } from './PlayerSlot';

type PlaybackSource = 'local' | 'remote';

export interface PipelineOrchestratorCallbacks {
  onEnterBuffering(frozenPositionMs: number): void;
  onExitBuffering(): void;
  onPhaseChanged(phase: PlaySinkPhase): void;
  onPositionChanged(positionMs: number): void;
  onDurationChanged(durationMs: number): void;
  onCompleted(): void;
  onError(message: string): void;
  getAuthoritativePositionMs(): number;
  getCurrentPhase(): string;
}

const MAX_REPLAY_RETRIES: number = 3;

/**
 * AVPlayer-only 播放编排：active / standby 双槽；首播 / 切网 / seek 共用 replayAt(HTTP URL)。
 */
export class PipelineOrchestrator implements AudioRenderSinkListener {
  private callbacks: PipelineOrchestratorCallbacks | null = null;
  private activeSlot: PlayerSlot = new PlayerSlot();
  private standbySlot: PlayerSlot | null = null;
  private migrating: boolean = false;
  private bufferingActive: boolean = false;
  private frozenPositionMs: number = 0;
  private wasPlayingBeforeBuffer: boolean = false;
  private durationMs: number = 0;
  private replayRetryTimerId: number = -1;
  private replayRetryCount: number = 0;
  private lastReplayUrl: string = '';
  private lastReplayLocalPath: string = '';
  private lastReplaySeekMs: number = 0;
  private lastReplayAutoPlay: boolean = false;
  private playbackSource: PlaybackSource = 'remote';
  /** replayAt(seek>0)：等 onReplayReady 再 exitBuffering */
  private awaitReplayReady: boolean = false;
  private standbyPrepareFailedCb: ((songId: string) => void) | null = null;

  constructor() {
    this.activeSlot.sink.setListener(this);
  }

  setContext(_context: common.UIAbilityContext): void {
  }

  setCallbacks(callbacks: PipelineOrchestratorCallbacks | null): void {
    this.callbacks = callbacks;
  }

  setStandbyPrepareFailedCallback(callback: ((songId: string) => void) | null): void {
    this.standbyPrepareFailedCb = callback;
  }

  async initialize(): Promise<void> {
    await this.activeSlot.sink.initialize();
  }

  async release(): Promise<void> {
    await this.cancel(false);
    await this.cancelStandby();
    await this.activeSlot.release();
  }

  getActiveStreamResource(): StreamResource | null {
    return this.activeSlot.streamResource;
  }

  setActiveStreamResource(resource: StreamResource | null): void {
    this.activeSlot.streamResource = resource;
  }

  async startTrack(streamResource: StreamResource, durationMs: number, autoPlay: boolean): Promise<void> {
    await this.cancel(false);
    this.activeSlot.streamResource = streamResource;
    this.activeSlot.songId = streamResource.songId;
    this.durationMs = durationMs;
    await this.replayAtCurrentTarget(0, autoPlay);
    PipelineMetrics.recordTrackStart();
  }

  async cancel(keepStreamResource: boolean = false): Promise<void> {
    this.clearReplayRetry();
    if (this.activeSlot.streamResource !== null && !keepStreamResource) {
      this.activeSlot.streamResource.cancelToken.cancel();
    }
    await this.activeSlot.sink.stop();
    this.bufferingActive = false;
    this.awaitReplayReady = false;
    this.migrating = false;
    this.replayRetryCount = 0;
    if (!keepStreamResource) {
      this.activeSlot.streamResource = null;
      this.activeSlot.songId = '';
    }
  }

  async prepareStandby(streamResource: StreamResource, _durationMs: number): Promise<boolean> {
    await this.cancelStandby();
    const slot: PlayerSlot = new PlayerSlot();
    slot.streamResource = streamResource;
    slot.songId = streamResource.songId;
    slot.sink.setStandbyPreparedCallback((): void => {
      slot.standbyReady = true;
    });
    slot.sink.setStandbyFailedCallback((): void => {
      this.standbyPrepareFailedCb?.(slot.songId);
      if (this.standbySlot === slot) {
        this.standbySlot = null;
      }
      void slot.release();
    });
    await slot.sink.initialize();
    const localPath: string | null = SongCache.resolveLocalPath(streamResource.songId);
    try {
      if (localPath !== null) {
        slot.playbackSource = 'local';
        slot.localPath = localPath;
        await slot.sink.openLocalFile(localPath, 0, false);
      } else {
        slot.playbackSource = 'remote';
        const url: string = streamResource.resolveRequest().url;
        await slot.sink.openUrl(url, 0, false);
      }
    } catch (err) {
      Logger.warn('PipelineOrchestrator', `prepareStandby failed: ${(err as Error).message}`);
      await slot.release();
      return false;
    }
    if (slot.sink.getPhase() === 'error') {
      await slot.release();
      return false;
    }
    this.standbySlot = slot;
    return true;
  }

  isStandbyReady(songId: string): boolean {
    if (this.standbySlot === null || this.standbySlot.songId !== songId) {
      return false;
    }
    if (!this.standbySlot.standbyReady) {
      return false;
    }
    const phase: PlaySinkPhase = this.standbySlot.sink.getPhase();
    return phase === 'paused';
  }

  async promoteStandbyToActive(autoPlay: boolean): Promise<boolean> {
    if (this.standbySlot === null || !this.standbySlot.standbyReady) {
      return false;
    }
    const promoted: PlayerSlot = this.standbySlot;
    this.standbySlot = null;
    promoted.sink.setStandbyPreparedCallback(null);
    promoted.sink.setStandbyFailedCallback(null);

    const oldActive: PlayerSlot = this.activeSlot;
    oldActive.sink.setListener(null);
    await oldActive.sink.release();

    this.activeSlot = promoted;
    promoted.sink.setListener(this);
    this.playbackSource = promoted.playbackSource;
    const fromSink: number = promoted.sink.getDurationMs();
    if (fromSink > 0) {
      this.durationMs = fromSink;
    }

    if (autoPlay) {
      await promoted.sink.play();
    }
    PipelineMetrics.recordTrackStart();
    return true;
  }

  async cancelStandby(): Promise<void> {
    if (this.standbySlot === null) {
      return;
    }
    const slot: PlayerSlot = this.standbySlot;
    this.standbySlot = null;
    await slot.release();
  }

  async migrateInPlace(frozenPositionMs: number, wasPlaying: boolean): Promise<void> {
    if (this.activeSlot.streamResource === null || this.migrating) {
      return;
    }
    if (this.playbackSource === 'local') {
      return;
    }
    this.migrating = true;
    this.clearReplayRetry();
    this.frozenPositionMs = frozenPositionMs;
    this.wasPlayingBeforeBuffer = wasPlaying;
    this.replayRetryCount = 0;
    this.enterBuffering(frozenPositionMs);
    await this.activeSlot.sink.stop();
    try {
      await PipelineOrchestrator.probeStreamEndpoint(this.activeSlot.streamResource.getEndpoint());
    } catch (err) {
      Logger.warn('PipelineOrchestrator', `endpoint probe: ${(err as Error).message}`);
    }
    this.activeSlot.streamResource.timeOffsetMs = 0;
    this.activeSlot.streamResource.byteOffset = 0;
    const url: string = this.resolveStreamUrl();
    await this.replayAt(url, frozenPositionMs, wasPlaying);
    PipelineMetrics.recordMigrate();
    this.migrating = false;
  }

  async onNetworkPathChanged(event: EndpointChangeEvent): Promise<void> {
    if (this.activeSlot.streamResource !== null) {
      this.activeSlot.streamResource.migrate(event.to);
    }
    if (this.standbySlot !== null) {
      await this.cancelStandby();
    }
    const frozenMs: number = this.callbacks?.getAuthoritativePositionMs() ?? this.frozenPositionMs;
    const phase: string = this.callbacks?.getCurrentPhase() ?? 'idle';
    const wasPlaying: boolean = phase === 'playing' || this.wasPlayingBeforeBuffer;
    if (this.activeSlot.streamResource === null) {
      return;
    }
    await this.migrateInPlace(frozenMs, wasPlaying);
  }

  async seek(positionMs: number): Promise<void> {
    if (this.activeSlot.streamResource === null) {
      return;
    }
    if (this.activeSlot.sink.canSeekInPlace()) {
      await this.activeSlot.sink.seek(positionMs);
      this.frozenPositionMs = positionMs;
      PipelineMetrics.recordSeek();
      return;
    }
    const wasPlaying: boolean = this.callbacks?.getCurrentPhase() === 'playing';
    await this.replayAtCurrentTarget(positionMs, wasPlaying);
    PipelineMetrics.recordSeek();
  }

  async play(): Promise<void> {
    const sinkPhase: PlaySinkPhase = this.activeSlot.sink.getPhase();
    if (sinkPhase === 'error' || sinkPhase === 'stopped' || sinkPhase === 'idle') {
      await this.resumeAfterError();
      return;
    }
    await this.activeSlot.sink.play();
  }

  async resumeAfterError(): Promise<void> {
    if (this.activeSlot.streamResource === null) {
      return;
    }
    const frozenMs: number = this.callbacks?.getAuthoritativePositionMs() ?? this.frozenPositionMs;
    await this.replayAtCurrentTarget(frozenMs > 0 ? frozenMs : this.activeSlot.sink.getPositionMs(), true);
  }

  async pause(): Promise<void> {
    await this.activeSlot.sink.pause();
  }

  getPositionMs(): number {
    if (this.bufferingActive) {
      return this.frozenPositionMs;
    }
    return this.activeSlot.sink.getPositionMs();
  }

  getDurationMs(): number {
    const fromSink: number = this.activeSlot.sink.getDurationMs();
    return fromSink > 0 ? fromSink : this.durationMs;
  }

  getPhase(): PlaySinkPhase {
    return this.activeSlot.sink.getPhase();
  }

  isBuffering(): boolean {
    return this.bufferingActive;
  }

  isAwaitingReplayReady(): boolean {
    return this.awaitReplayReady;
  }

  private async replayAtCurrentTarget(seekMs: number, shouldResumeAfterLoad: boolean): Promise<void> {
    if (this.activeSlot.streamResource === null) {
      return;
    }
    const localPath: string | null = SongCache.resolveLocalPath(this.activeSlot.streamResource.songId);
    if (localPath !== null) {
      this.playbackSource = 'local';
      this.activeSlot.playbackSource = 'local';
      this.activeSlot.localPath = localPath;
      await this.replayAtLocal(localPath, seekMs, shouldResumeAfterLoad);
      return;
    }
    this.playbackSource = 'remote';
    this.activeSlot.playbackSource = 'remote';
    const url: string = this.resolveStreamUrl();
    await this.replayAt(url, seekMs, shouldResumeAfterLoad);
  }

  /** open → prepare → play → seek(切网) → 退出 buffering 后按需恢复播放 */
  private async replayAt(url: string, seekMs: number, shouldResumeAfterLoad: boolean): Promise<void> {
    this.lastReplayUrl = url;
    this.lastReplayLocalPath = '';
    this.lastReplaySeekMs = seekMs;
    this.lastReplayAutoPlay = shouldResumeAfterLoad;
    this.awaitReplayReady = seekMs > 0;
    if (seekMs > 0 && !this.bufferingActive) {
      this.wasPlayingBeforeBuffer = shouldResumeAfterLoad;
      this.enterBuffering(seekMs);
    }
    const autoPlayDuringLoad: boolean = seekMs === 0 && shouldResumeAfterLoad && !this.bufferingActive;
    try {
      await this.activeSlot.sink.openUrl(url, seekMs, autoPlayDuringLoad);
    } catch (err) {
      Logger.warn('PipelineOrchestrator', `replayAt failed: ${(err as Error).message}`);
      this.callbacks?.onError((err as Error).message);
    }
  }

  private async replayAtLocal(localPath: string, seekMs: number, shouldResumeAfterLoad: boolean): Promise<void> {
    this.lastReplayLocalPath = localPath;
    this.lastReplayUrl = '';
    this.lastReplaySeekMs = seekMs;
    this.lastReplayAutoPlay = shouldResumeAfterLoad;
    this.awaitReplayReady = seekMs > 0;
    if (seekMs > 0 && !this.bufferingActive) {
      this.wasPlayingBeforeBuffer = shouldResumeAfterLoad;
      this.enterBuffering(seekMs);
    }
    const autoPlayDuringLoad: boolean = seekMs === 0 && shouldResumeAfterLoad && !this.bufferingActive;
    try {
      await this.activeSlot.sink.openLocalFile(localPath, seekMs, autoPlayDuringLoad);
    } catch (err) {
      const error: Error = err as Error;
      Logger.warn('PipelineOrchestrator', `replayAtLocal failed: ${error.message}`);
      if (this.activeSlot.streamResource !== null &&
        SongCache.shouldInvalidateLocalCache(localPath, error)) {
        await SongCache.removeEntry(this.activeSlot.streamResource.songId);
      }
      this.playbackSource = 'remote';
      this.activeSlot.playbackSource = 'remote';
      const url: string = this.resolveStreamUrl();
      await this.replayAt(url, seekMs, shouldResumeAfterLoad);
    }
  }

  private static async probeStreamEndpoint(endpoint: EndpointType): Promise<void> {
    const creds = AuthStore.getInstance().getCredentials();
    if (creds === null) {
      return;
    }
    const pingUrl: string = AuthContext.buildRestUrl('ping.view', [], creds, endpoint);
    await HttpTransport.probeRest(pingUrl);
  }

  private resolveStreamUrl(): string {
    if (this.activeSlot.streamResource === null) {
      return '';
    }
    return this.activeSlot.streamResource.resolveRequest().url;
  }

  private enterBuffering(frozenPositionMs: number): void {
    this.bufferingActive = true;
    this.frozenPositionMs = frozenPositionMs;
    this.callbacks?.onEnterBuffering(frozenPositionMs);
  }

  private exitBuffering(): void {
    if (!this.bufferingActive) {
      return;
    }
    const shouldResume: boolean = this.wasPlayingBeforeBuffer;
    const targetMs: number = this.frozenPositionMs;
    this.bufferingActive = false;
    this.wasPlayingBeforeBuffer = false;
    this.replayRetryCount = 0;
    this.callbacks?.onExitBuffering();
    void this.resumeAfterBufferingExit(shouldResume, targetMs);
  }

  private async resumeAfterBufferingExit(shouldResume: boolean, targetMs: number): Promise<void> {
    if (targetMs > 0) {
      const currentMs: number = this.activeSlot.sink.getPositionMs();
      if (Math.abs(currentMs - targetMs) > 1500) {
        await this.activeSlot.sink.seek(targetMs);
      }
    }
    if (shouldResume) {
      await this.activeSlot.sink.play();
    }
  }

  private clearReplayRetry(): void {
    if (this.replayRetryTimerId >= 0) {
      clearTimeout(this.replayRetryTimerId);
      this.replayRetryTimerId = -1;
    }
  }

  private scheduleReplayRetry(): void {
    if (!this.bufferingActive ||
      (this.lastReplayUrl.length === 0 && this.lastReplayLocalPath.length === 0)) {
      return;
    }
    if (this.replayRetryCount >= MAX_REPLAY_RETRIES) {
      Logger.warn('PipelineOrchestrator', 'replay retries exhausted');
      this.bufferingActive = false;
      this.callbacks?.onError('replay retries exhausted');
      return;
    }
    this.replayRetryCount++;
    const delayMs: number = 1500 * this.replayRetryCount;
    this.clearReplayRetry();
    this.replayRetryTimerId = setTimeout((): void => {
      this.replayRetryTimerId = -1;
      if (!this.bufferingActive ||
        (this.lastReplayUrl.length === 0 && this.lastReplayLocalPath.length === 0)) {
        return;
      }
      Logger.info('PipelineOrchestrator',
        `retry replay attempt=${this.replayRetryCount} pos=${this.frozenPositionMs}`);
      void this.retryReplayAfterError();
    }, delayMs);
  }

  private retryReplayAfterError(): void {
    if (!this.bufferingActive || this.activeSlot.streamResource === null) {
      return;
    }
    this.activeSlot.streamResource.timeOffsetMs = 0;
    const seekMs: number = this.frozenPositionMs > 0 ? this.frozenPositionMs : this.lastReplaySeekMs;
    void this.replayAtCurrentTarget(seekMs, this.lastReplayAutoPlay);
  }

  onPhaseChanged(phase: PlaySinkPhase): void {
    if (this.bufferingActive && !this.awaitReplayReady) {
      const replayDone: boolean =
        phase === 'playing' ||
        (phase === 'paused' && !this.lastReplayAutoPlay);
      if (replayDone) {
        this.exitBuffering();
      }
    }
    this.callbacks?.onPhaseChanged(phase);
  }

  onReplayReady(positionMs: number): void {
    this.awaitReplayReady = false;
    if (this.activeSlot.streamResource !== null) {
      this.activeSlot.streamResource.timeOffsetMs = 0;
    }
    const reportPos: number =
      this.bufferingActive && this.frozenPositionMs > 0 ? this.frozenPositionMs : positionMs;
    if (this.bufferingActive) {
      this.exitBuffering();
    }
    this.callbacks?.onPositionChanged(reportPos);
  }

  onPositionChanged(positionMs: number): void {
    if (!this.bufferingActive) {
      this.callbacks?.onPositionChanged(positionMs);
    }
  }

  onDurationChanged(durationMs: number): void {
    if (durationMs > 0) {
      this.durationMs = durationMs;
    }
    this.callbacks?.onDurationChanged(durationMs);
  }

  onCompleted(): void {
    this.callbacks?.onCompleted();
  }

  onError(message: string): void {
    Logger.warn('PipelineOrchestrator', message);
    if (this.bufferingActive) {
      this.scheduleReplayRetry();
    }
    this.callbacks?.onError(message);
  }
}
