import { Logger } from '../../common/Logger';
import { NextTrackPreloadStrategy, PreloadDeps } from './NextTrackPreloadStrategy';
import { PreloadContext, PreloadHandle } from './NextTrackPreloadTypes';

export class PlayerStandbyPreloadStrategy implements NextTrackPreloadStrategy {
  readonly name: string = 'standby';

  canApply(ctx: PreloadContext, deps: PreloadDeps): boolean {
    if (deps.isComplete(ctx.nextSong.id)) {
      return false;
    }
    return deps.isStandbyCapable();
  }

  start(ctx: PreloadContext, deps: PreloadDeps): PreloadHandle {
    const resource = deps.openStream(ctx.nextSong.id);
    const durationMs: number = ctx.nextSong.duration > 0 ? ctx.nextSong.duration * 1000 : 0;
    Logger.debug('PlayerStandbyPreloadStrategy', `prepareStandby songId=${ctx.nextSong.id}`);
    void deps.orchestrator.prepareStandby(resource, durationMs).then((ok: boolean): void => {
      if (!ok) {
        deps.onStandbyPrepareFailed(ctx.nextSong.id);
      }
    });
    return { kind: 'standby', songId: ctx.nextSong.id, streamResource: resource };
  }

  cancel(_handle: PreloadHandle, _deps: PreloadDeps): void {
  }
}
