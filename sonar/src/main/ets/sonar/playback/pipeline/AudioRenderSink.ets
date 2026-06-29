import { fileIo } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { Logger } from '../../common/Logger';

export type PlaySinkPhase = 'idle' | 'loading' | 'playing' | 'paused' | 'stopped' | 'error';

/** openUrl 内 seek 超时（远程 HTTP seek 可能长时间挂起） */
const OPEN_SEEK_TIMEOUT_MS: number = 20000;

export interface AudioRenderSinkListener {
  onPhaseChanged(phase: PlaySinkPhase): void;
  onPositionChanged(positionMs: number): void;
  onDurationChanged(durationMs: number): void;
  /** seek>0 续播：先 play 再 seek 完成，可安全退出 loading / buffering */
  onReplayReady(positionMs: number): void;
  onCompleted(): void;
  onError(message: string): void;
}

/**
 * AVPlayer HTTP 播放：open → prepare → play → seek(切网/续播) 或 prepare → seek(仅定位)。
 */
export class AudioRenderSink {
  private listener: AudioRenderSinkListener | null = null;
  private player: media.AVPlayer | null = null;
  private phase: PlaySinkPhase = 'idle';
  private pendingAutoPlay: boolean = false;
  private pendingSeekMs: number = 0;
  /** seek>0 且需续播：先 play 拉流，进入 playing 后再 seek（等同手动拖进度条） */
  private seekAfterPlayStart: boolean = false;
  private autoPlayAfterSeek: boolean = false;
  private seekHandled: boolean = false;
  /** openUrl(seek>0) 完成定位后通知编排层 */
  private pendingOpenSeekComplete: boolean = false;
  private openGeneration: number = 0;
  private reopeningStream: boolean = false;
  private activeOpenGen: number = 0;
  private positionMs: number = 0;
  private durationMs: number = 0;
  private seekTimeoutTimerId: number = -1;
  private localFile: fileIo.File | null = null;
  private standbyPreparedCallback: (() => void) | null = null;
  private standbyFailedCallback: (() => void) | null = null;

  setStandbyPreparedCallback(callback: (() => void) | null): void {
    this.standbyPreparedCallback = callback;
  }

  setStandbyFailedCallback(callback: (() => void) | null): void {
    this.standbyFailedCallback = callback;
  }

  setListener(listener: AudioRenderSinkListener | null): void {
    this.listener = listener;
  }

  getPhase(): PlaySinkPhase {
    return this.phase;
  }

  getPositionMs(): number {
    return this.positionMs;
  }

  getDurationMs(): number {
    return this.durationMs;
  }

  canSeekInPlace(): boolean {
    const player: media.AVPlayer | null = this.player;
    if (player === null || this.phase === 'error' || this.phase === 'idle') {
      return false;
    }
    const state: string = player.state;
    return state === 'prepared' || state === 'playing' || state === 'paused' || state === 'completed';
  }

  async initialize(): Promise<void> {
    await this.ensurePlayer();
  }

  async release(): Promise<void> {
    this.clearPendingOpen();
    this.closeLocalFile();
    if (this.player !== null) {
      try {
        await this.player.release();
      } catch (err) {
        Logger.warn('AudioRenderSink', `release failed: ${(err as Error).message}`);
      }
      this.player = null;
    }
    this.setPhase('idle');
    this.positionMs = 0;
    this.durationMs = 0;
  }

  /** 在新 HTTP URL 上打开流 */
  async openUrl(url: string, seekMs: number, autoPlay: boolean): Promise<void> {
    await this.recyclePlayerIfBroken();
    this.openGeneration++;
    const generation: number = this.openGeneration;
    let player: media.AVPlayer = await this.ensurePlayer();
    this.clearPendingOpen();
    this.pendingSeekMs = seekMs;
    this.pendingAutoPlay = autoPlay;
    /** seek>0 必须 play 后再 seek；prepared 态直接 seek 在部分 endpoint 会 IO 失败 */
    this.seekAfterPlayStart = seekMs > 0;
    this.autoPlayAfterSeek = false;
    this.pendingOpenSeekComplete = seekMs > 0;
    this.reopeningStream = true;
    this.activeOpenGen = 0;
    this.setPhase('loading');
    player = await this.resetPlayerForNewUrl(player);
    if (generation !== this.openGeneration) {
      this.reopeningStream = false;
      return;
    }
    player.url = url;
    this.activeOpenGen = generation;
  }

  /** 本地缓存文件播放（fdSrc） */
  async openLocalFile(path: string, seekMs: number, autoPlay: boolean): Promise<void> {
    await this.recyclePlayerIfBroken();
    this.openGeneration++;
    const generation: number = this.openGeneration;
    let player: media.AVPlayer = await this.ensurePlayer();
    this.clearPendingOpen();
    this.pendingSeekMs = seekMs;
    this.pendingAutoPlay = autoPlay;
    this.seekAfterPlayStart = seekMs > 0;
    this.autoPlayAfterSeek = false;
    this.pendingOpenSeekComplete = seekMs > 0;
    this.reopeningStream = true;
    this.activeOpenGen = 0;
    this.setPhase('loading');
    player = await this.resetPlayerForNewUrl(player);
    if (generation !== this.openGeneration) {
      this.reopeningStream = false;
      return;
    }
    this.closeLocalFile();
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    } catch (err) {
      Logger.warn('AudioRenderSink', `openLocalFile open failed: ${(err as Error).message}`);
      this.reopeningStream = false;
      this.setPhase('error');
      return;
    }
    let fileSize: number = 0;
    try {
      fileSize = fileIo.statSync(path).size;
    } catch (err) {
      try {
        fileIo.closeSync(file);
      } catch (_closeErr) {
      }
      Logger.warn('AudioRenderSink', `openLocalFile stat failed: ${(err as Error).message}`);
      this.reopeningStream = false;
      this.setPhase('error');
      return;
    }
    this.localFile = file;
    player.fdSrc = {
      fd: file.fd,
      offset: 0,
      length: fileSize
    };
    this.activeOpenGen = generation;
  }

  async play(): Promise<void> {
    const player: media.AVPlayer = await this.ensurePlayer();
    const state: string = player.state;
    if (state === 'playing') {
      return;
    }
    const canPlay: boolean = state === 'prepared' || state === 'paused' || state === 'completed';
    if (!canPlay) {
      Logger.warn('AudioRenderSink', `play ignored in state=${state}`);
      return;
    }
    try {
      await player.play();
    } catch (err) {
      this.emitError(`play failed: ${(err as Error).message}`);
    }
  }

  async pause(): Promise<void> {
    const player: media.AVPlayer | null = this.player;
    if (player === null || player.state !== 'playing') {
      return;
    }
    try {
      await player.pause();
    } catch (err) {
      Logger.warn('AudioRenderSink', `pause failed: ${(err as Error).message}`);
    }
  }

  async stop(): Promise<void> {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      this.setPhase('stopped');
      return;
    }
    const state: string = player.state;
    if (state !== 'prepared' && state !== 'playing' && state !== 'paused' && state !== 'completed') {
      this.setPhase('stopped');
      return;
    }
    try {
      await player.stop();
    } catch (err) {
      Logger.warn('AudioRenderSink', `stop failed: ${(err as Error).message}`);
    }
    this.setPhase('stopped');
  }

  async seek(positionMs: number): Promise<void> {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    try {
      await player.seek(positionMs);
      this.positionMs = positionMs;
      this.listener?.onPositionChanged(this.positionMs);
    } catch (err) {
      Logger.warn('AudioRenderSink', `seek failed: ${(err as Error).message}`);
    }
  }

  private clearPendingOpen(): void {
    this.pendingAutoPlay = false;
    this.pendingSeekMs = 0;
    this.seekAfterPlayStart = false;
    this.autoPlayAfterSeek = false;
    this.seekHandled = false;
    this.pendingOpenSeekComplete = false;
    this.clearSeekTimeout();
  }

  private async recyclePlayerIfBroken(): Promise<void> {
    if (this.player === null || this.phase !== 'error') {
      return;
    }
    try {
      await this.player.release();
    } catch (_err) {
    }
    this.player = null;
    this.phase = 'idle';
  }

  private async ensurePlayer(): Promise<media.AVPlayer> {
    if (this.player !== null) {
      return this.player;
    }
    try {
      const created: media.AVPlayer = await media.createAVPlayer();
      created.on('stateChange', (state: string) => {
        void this.onPlayerStateChange(state);
      });
      created.on('timeUpdate', (time: number) => {
        if (this.pendingOpenSeekComplete) {
          return;
        }
        this.positionMs = time;
        this.listener?.onPositionChanged(time);
      });
      created.on('durationUpdate', (duration: number) => {
        if (duration > 0) {
          this.durationMs = duration;
          this.listener?.onDurationChanged(duration);
        }
      });
      created.on('error', (err: Error) => {
        this.emitError(`player error: ${err.message}`);
      });
      try {
        created.on('seekDone', (seekDoneTime: number) => {
          void this.triggerSeekDone(seekDoneTime);
        });
      } catch (_err) {
      }
      this.player = created;
      return created;
    } catch (err) {
      throw new Error(`createAVPlayer failed: ${(err as Error).message}`);
    }
  }

  private closeLocalFile(): void {
    if (this.localFile === null) {
      return;
    }
    try {
      fileIo.closeSync(this.localFile);
    } catch (_err) {
    }
    this.localFile = null;
  }

  private async resetPlayerForNewUrl(player: media.AVPlayer): Promise<media.AVPlayer> {
    this.closeLocalFile();
    try {
      const state: string = player.state;
      if (state === 'playing') {
        await player.pause();
      }
      if (state === 'playing' || state === 'paused' || state === 'completed' || state === 'prepared') {
        await player.stop();
      }
      if (player.state !== 'idle') {
        await player.reset();
      }
      return player;
    } catch (err) {
      Logger.warn('AudioRenderSink', `reset for new url failed: ${(err as Error).message}`);
      try {
        await player.release();
      } catch (_releaseErr) {
      }
      this.player = null;
      return await this.ensurePlayer();
    }
  }

  private async onPlayerStateChange(state: string): Promise<void> {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    if (this.activeOpenGen === 0 || this.activeOpenGen !== this.openGeneration) {
      return;
    }
    if (state === 'initialized') {
      try {
        await player.prepare();
      } catch (err) {
        this.emitError(`prepare failed: ${(err as Error).message}`);
      }
      return;
    }
    if (state === 'prepared') {
      this.reopeningStream = false;
      if (this.seekAfterPlayStart) {
        try {
          await player.play();
        } catch (err) {
          this.emitError(`play for seek failed: ${(err as Error).message}`);
        }
        return;
      }
      if (this.pendingSeekMs > 0) {
        const seekTarget: number = this.pendingSeekMs;
        this.pendingSeekMs = 0;
        this.autoPlayAfterSeek = this.pendingAutoPlay;
        this.pendingAutoPlay = false;
        this.seekHandled = false;
        try {
          await player.seek(seekTarget);
        } catch (err) {
          Logger.warn('AudioRenderSink', `prepared seek failed: ${(err as Error).message}`);
          this.autoPlayAfterSeek = false;
          this.emitError(`prepared seek failed: ${(err as Error).message}`);
        }
        return;
      }
      await this.finishPreparedWithoutSeek(player);
      return;
    }
    if (state === 'playing') {
      if (this.pendingOpenSeekComplete) {
        if (this.seekAfterPlayStart && this.pendingSeekMs > 0) {
          await this.seekAfterPlayingStarted(player);
        }
        return;
      }
      this.setPhase('playing');
      return;
    }
    if (state === 'paused' || state === 'stopped') {
      if (this.reopeningStream && state === 'stopped') {
        return;
      }
      this.setPhase(state === 'paused' ? 'paused' : 'stopped');
      return;
    }
    if (state === 'completed') {
      this.setPhase('stopped');
      this.listener?.onCompleted();
    }
  }

  /** 切网续播：playing 后再 seek，避免 prepared 态 seek 导致 play 失败 */
  private async seekAfterPlayingStarted(player: media.AVPlayer): Promise<void> {
    if (!this.seekAfterPlayStart || this.pendingSeekMs <= 0) {
      return;
    }
    this.seekAfterPlayStart = false;
    const seekTarget: number = this.pendingSeekMs;
    this.pendingSeekMs = 0;
    this.pendingAutoPlay = false;
    this.autoPlayAfterSeek = false;
    this.seekHandled = false;
    this.armSeekTimeout();
    try {
      await player.seek(seekTarget);
    } catch (err) {
      Logger.warn('AudioRenderSink', `seek after play failed: ${(err as Error).message}`);
      this.emitError(`seek after play failed: ${(err as Error).message}`);
    }
  }

  private async triggerSeekDone(seekDoneTime: number): Promise<void> {
    if (this.seekHandled) {
      return;
    }
    this.seekHandled = true;
    await this.onSeekDone(seekDoneTime);
  }

  private async onSeekDone(seekDoneTime: number): Promise<void> {
    const player: media.AVPlayer | null = this.player;
    if (player === null || this.activeOpenGen !== this.openGeneration) {
      return;
    }
    this.positionMs = seekDoneTime;
    this.clearSeekTimeout();
    if (this.pendingOpenSeekComplete) {
      this.pendingOpenSeekComplete = false;
      if (player.state === 'playing') {
        try {
          await player.pause();
        } catch (err) {
          Logger.warn('AudioRenderSink', `pause after open seek failed: ${(err as Error).message}`);
        }
      }
      this.setPhase('paused');
      this.listener?.onReplayReady(seekDoneTime);
      return;
    }
    this.listener?.onPositionChanged(seekDoneTime);
    if (this.autoPlayAfterSeek) {
      this.autoPlayAfterSeek = false;
      try {
        await player.play();
      } catch (err) {
        this.emitError(`auto play after seek failed: ${(err as Error).message}`);
      }
      return;
    }
    if (player.state === 'playing') {
      return;
    }
    this.setPhase('paused');
  }

  private async finishPreparedWithoutSeek(player: media.AVPlayer): Promise<void> {
    if (this.pendingAutoPlay) {
      this.pendingAutoPlay = false;
      try {
        await player.play();
      } catch (err) {
        this.emitError(`auto play failed: ${(err as Error).message}`);
      }
      return;
    }
    this.setPhase('paused');
    if (this.standbyPreparedCallback !== null) {
      this.standbyPreparedCallback();
    }
  }

  private armSeekTimeout(): void {
    this.clearSeekTimeout();
    this.seekTimeoutTimerId = setTimeout((): void => {
      this.seekTimeoutTimerId = -1;
      if (this.pendingOpenSeekComplete) {
        this.pendingOpenSeekComplete = false;
        this.emitError(`open seek timeout after ${OPEN_SEEK_TIMEOUT_MS}ms`);
      }
    }, OPEN_SEEK_TIMEOUT_MS);
  }

  private clearSeekTimeout(): void {
    if (this.seekTimeoutTimerId < 0) {
      return;
    }
    clearTimeout(this.seekTimeoutTimerId);
    this.seekTimeoutTimerId = -1;
  }

  private setPhase(phase: PlaySinkPhase): void {
    if (this.phase === phase) {
      return;
    }
    this.phase = phase;
    this.listener?.onPhaseChanged(phase);
  }

  private emitError(message: string): void {
    this.reopeningStream = false;
    this.seekAfterPlayStart = false;
    this.pendingOpenSeekComplete = false;
    this.clearSeekTimeout();
    Logger.warn('AudioRenderSink', message);
    if (this.standbyFailedCallback !== null && this.standbyPreparedCallback !== null) {
      const failedCb: () => void = this.standbyFailedCallback;
      this.standbyFailedCallback = null;
      this.standbyPreparedCallback = null;
      failedCb();
      return;
    }
    if (this.phase !== 'error') {
      this.setPhase('error');
      this.listener?.onError(message);
    }
  }
}
