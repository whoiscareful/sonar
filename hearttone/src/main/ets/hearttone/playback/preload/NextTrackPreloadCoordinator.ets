import { EndpointRouter } from '../../network/routing/EndpointRouter';
import { Logger } from '../../common/Logger';
import { NextTrackPreloadStrategy, PreloadDeps } from './NextTrackPreloadStrategy';
import {
  NEXT_PRELOAD_REMAINING_MS,
  PreloadContext,
  PreloadHandle,
  PreloadPhase
} from './NextTrackPreloadTypes';
import { PlayerStandbyPreloadStrategy } from './PlayerStandbyPreloadStrategy';
import { SkipPreloadStrategy } from './SkipPreloadStrategy';
import { SongCacheDownloadPreloadStrategy } from './SongCacheDownloadPreloadStrategy';
import { StreamWarmupPreloadStrategy } from './StreamWarmupPreloadStrategy';

const STREAMING_STRATEGY_NAMES: string[] = ['standby', 'streamWarmup'];

export class NextTrackPreloadCoordinator {
  private readonly deps: PreloadDeps;
  private readonly strategies: NextTrackPreloadStrategy[];
  private readonly strategyByName: Map<string, NextTrackPreloadStrategy> = new Map<string, NextTrackPreloadStrategy>();
  private phase: PreloadPhase = PreloadPhase.Idle;
  private activeNextSongId: string = '';
  private readonly handles: Map<string, PreloadHandle> = new Map<string, PreloadHandle>();
  private lastContext: PreloadContext | null = null;

  constructor(deps: PreloadDeps) {
    this.deps = deps;
    this.strategies = [
      new SkipPreloadStrategy(),
      new SongCacheDownloadPreloadStrategy(),
      new PlayerStandbyPreloadStrategy(),
      new StreamWarmupPreloadStrategy()
    ];
    for (let i: number = 0; i < this.strategies.length; i++) {
      this.strategyByName.set(this.strategies[i].name, this.strategies[i]);
    }
  }

  onProgressTick(ctx: PreloadContext): void {
    this.lastContext = ctx;
    if (ctx.phase !== 'playing') {
      return;
    }
    if (ctx.remainingMs <= NEXT_PRELOAD_REMAINING_MS && ctx.remainingMs > 0) {
      this.ensureStarted(ctx);
      return;
    }
    if (ctx.remainingMs > NEXT_PRELOAD_REMAINING_MS) {
      this.cancelOutOfWindow();
    }
  }

  reset(): void {
    this.cancelStreamingOnly();
    this.handles.clear();
    this.phase = PreloadPhase.Idle;
    this.activeNextSongId = '';
    this.lastContext = null;
  }

  onEndpointChanged(): void {
    this.cancelStreamingOnly();
    if (this.lastContext === null) {
      return;
    }
    const ctx: PreloadContext = this.refreshContextEndpoint(this.lastContext);
    this.lastContext = ctx;
    if (ctx.phase !== 'playing') {
      return;
    }
    if (ctx.remainingMs <= NEXT_PRELOAD_REMAINING_MS && ctx.remainingMs > 0) {
      this.activeNextSongId = '';
      this.handles.clear();
      this.phase = PreloadPhase.Idle;
      this.ensureStarted(ctx);
    }
  }

  handleStandbyPrepareFailed(songId: string): void {
    if (this.handles.get('standby')?.songId !== songId) {
      return;
    }
    this.handles.delete('standby');
    Logger.warn('NextTrackPreloadCoordinator', `standby prepare failed songId=${songId}`);
    if (this.handles.size === 0 || (this.handles.size === 1 && this.handles.has('download'))) {
      if (!this.handles.has('download')) {
        this.phase = PreloadPhase.Idle;
        this.activeNextSongId = '';
      }
    }
  }

  private refreshContextEndpoint(ctx: PreloadContext): PreloadContext {
    return {
      currentSongId: ctx.currentSongId,
      nextSong: ctx.nextSong,
      remainingMs: ctx.remainingMs,
      durationMs: ctx.durationMs,
      phase: ctx.phase,
      endpoint: EndpointRouter.getActiveEndpoint()
    };
  }

  private ensureStarted(ctx: PreloadContext): void {
    const skip: NextTrackPreloadStrategy | undefined = this.strategyByName.get('skip');
    if (skip !== undefined && skip.canApply(ctx, this.deps)) {
      this.cancelStreamingOnly();
      this.handles.clear();
      this.phase = PreloadPhase.Idle;
      this.activeNextSongId = '';
      return;
    }
    if (this.activeNextSongId.length > 0 &&
      this.activeNextSongId !== ctx.nextSong.id) {
      this.cancelStreamingOnly();
      this.handles.clear();
      this.phase = PreloadPhase.Idle;
    }
    this.activeNextSongId = ctx.nextSong.id;
    this.phase = PreloadPhase.Running;
    for (let i: number = 0; i < this.strategies.length; i++) {
      const strategy: NextTrackPreloadStrategy = this.strategies[i];
      if (strategy.name === 'skip') {
        continue;
      }
      if (!strategy.canApply(ctx, this.deps)) {
        continue;
      }
      if (this.handles.has(strategy.name)) {
        continue;
      }
      const handle: PreloadHandle = strategy.start(ctx, this.deps);
      this.handles.set(strategy.name, handle);
      Logger.debug('NextTrackPreloadCoordinator', `started strategy=${strategy.name} songId=${ctx.nextSong.id}`);
    }
  }

  private cancelOutOfWindow(): void {
    this.cancelStreamingOnly();
    if (this.handles.size === 0 ||
      (this.handles.size === 1 && this.handles.has('download'))) {
      if (!this.handles.has('download')) {
        this.phase = PreloadPhase.Idle;
        this.activeNextSongId = '';
      }
    }
  }

  /** 取消 standby / streamWarmup；download 入队任务保留 */
  private cancelStreamingOnly(): void {
    let hadStandby: boolean = false;
    for (let i: number = 0; i < STREAMING_STRATEGY_NAMES.length; i++) {
      const name: string = STREAMING_STRATEGY_NAMES[i];
      const handle: PreloadHandle | undefined = this.handles.get(name);
      if (handle === undefined) {
        continue;
      }
      if (name === 'standby') {
        hadStandby = true;
      }
      const strategy: NextTrackPreloadStrategy | undefined = this.strategyByName.get(name);
      strategy?.cancel(handle, this.deps);
      this.handles.delete(name);
    }
    if (hadStandby) {
      void this.deps.orchestrator.cancelStandby();
    }
  }
}
