import { NextTrackPreloadStrategy, PreloadDeps } from './NextTrackPreloadStrategy';
import { PreloadContext, PreloadHandle } from './NextTrackPreloadTypes';

export class SongCacheDownloadPreloadStrategy implements NextTrackPreloadStrategy {
  readonly name: string = 'download';

  canApply(ctx: PreloadContext, deps: PreloadDeps): boolean {
    if (deps.isComplete(ctx.nextSong.id)) {
      return false;
    }
    return deps.shouldAutoCacheNow();
  }

  start(ctx: PreloadContext, deps: PreloadDeps): PreloadHandle {
    deps.enqueueDownload(ctx.nextSong.id);
    return { kind: 'download', songId: ctx.nextSong.id };
  }

  cancel(_handle: PreloadHandle, _deps: PreloadDeps): void {
  }
}
