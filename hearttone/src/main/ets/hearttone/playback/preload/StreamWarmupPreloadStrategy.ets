import { AuthContext } from '../../network/auth/AuthContext';
import { Logger } from '../../common/Logger';
import { CancelToken } from '../../network/transport/CancelToken';
import { HttpTransport } from '../../network/transport/HttpTransport';
import { NextTrackPreloadStrategy, PreloadDeps } from './NextTrackPreloadStrategy';
import { PreloadContext, PreloadHandle, STREAM_WARMUP_TARGET_BYTES } from './NextTrackPreloadTypes';

export class StreamWarmupPreloadStrategy implements NextTrackPreloadStrategy {
  readonly name: string = 'streamWarmup';

  canApply(ctx: PreloadContext, deps: PreloadDeps): boolean {
    if (deps.isComplete(ctx.nextSong.id)) {
      return false;
    }
    return !deps.isStandbyCapable();
  }

  start(ctx: PreloadContext, deps: PreloadDeps): PreloadHandle {
    const cancelToken: CancelToken = new CancelToken();
    const url: string = AuthContext.buildMediaUrl(
      'stream',
      ['id', ctx.nextSong.id],
      undefined,
      ctx.endpoint
    );
    let receivedBytes: number = 0;
    Logger.debug('StreamWarmupPreloadStrategy', `warmup songId=${ctx.nextSong.id}`);
    HttpTransport.openStream({
      url: url,
      byteOffset: 0,
      cancelToken: cancelToken,
      onChunk: (chunk: ArrayBuffer): void => {
        receivedBytes += chunk.byteLength;
        if (receivedBytes >= STREAM_WARMUP_TARGET_BYTES) {
          cancelToken.cancel();
        }
      },
      onComplete: (): void => {
      },
      onError: (_err: Error): void => {
      }
    });
    return { kind: 'streamWarmup', songId: ctx.nextSong.id, cancelToken: cancelToken };
  }

  cancel(handle: PreloadHandle, _deps: PreloadDeps): void {
    if (handle.cancelToken !== undefined) {
      handle.cancelToken.cancel();
    }
  }
}
