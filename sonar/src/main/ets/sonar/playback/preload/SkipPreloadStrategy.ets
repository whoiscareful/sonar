import { NextTrackPreloadStrategy, PreloadDeps } from './NextTrackPreloadStrategy';
import { PreloadContext, PreloadHandle } from './NextTrackPreloadTypes';

export class SkipPreloadStrategy implements NextTrackPreloadStrategy {
  readonly name: string = 'skip';

  canApply(_ctx: PreloadContext, deps: PreloadDeps): boolean {
    return deps.isComplete(_ctx.nextSong.id);
  }

  start(ctx: PreloadContext, _deps: PreloadDeps): PreloadHandle {
    return { kind: 'skip', songId: ctx.nextSong.id };
  }

  cancel(_handle: PreloadHandle, _deps: PreloadDeps): void {
  }
}
