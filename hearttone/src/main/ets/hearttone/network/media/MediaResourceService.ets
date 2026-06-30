import { EndpointType } from '../../auth/AuthStore';
import { AuthContext } from '../auth/AuthContext';
import { EndpointRouter } from '../routing/EndpointRouter';
import { EndpointChangeEvent } from '../routing/EndpointTypes';
import { CancelToken } from '../transport/CancelToken';
import { StreamResource } from './StreamResource';

export interface CoverResourceSpec {
  url: string;
  cancelToken: CancelToken;
}

export interface OpenStreamOptions {
  byteOffset?: number;
  maxBitRate?: number;
  cancelToken?: CancelToken;
}

export class MediaResourceService {
  private static activeStreams: StreamResource[] = [];
  private static unsubscribeRouter: (() => void) | null = null;

  static ensureRouterSubscription(): void {
    if (MediaResourceService.unsubscribeRouter !== null) {
      return;
    }
    MediaResourceService.unsubscribeRouter = EndpointRouter.subscribe((event: EndpointChangeEvent): void => {
      MediaResourceService.onEndpointChanged(event.to);
    });
  }

  static openStream(songId: string, opts?: OpenStreamOptions): StreamResource {
    MediaResourceService.ensureRouterSubscription();
    const endpoint: EndpointType = EndpointRouter.getActiveEndpoint();
    const cancelToken: CancelToken = opts !== undefined && opts.cancelToken !== undefined
      ? opts.cancelToken
      : new CancelToken();
    const byteOffset: number = opts !== undefined && opts.byteOffset !== undefined ? opts.byteOffset : 0;
    const maxBitRate: number = opts !== undefined && opts.maxBitRate !== undefined ? opts.maxBitRate : 0;
    const resource: StreamResource = new StreamResource(
      songId,
      endpoint,
      byteOffset,
      maxBitRate,
      cancelToken
    );
    MediaResourceService.activeStreams.push(resource);
    cancelToken.onCancel((): void => {
      MediaResourceService.removeStream(resource);
    });
    return resource;
  }

  static openCover(coverArtId: string, size: number = 300): CoverResourceSpec {
    const cancelToken: CancelToken = new CancelToken();
    const url: string = AuthContext.buildMediaUrl('getCoverArt', ['id', coverArtId, 'size', String(size)]);
    const spec: CoverResourceSpec = { url: url, cancelToken: cancelToken };
    return spec;
  }

  static buildCoverDisplayUrl(coverArtId: string, size: number = 300): string {
    return AuthContext.buildMediaUrl('getCoverArt', ['id', coverArtId, 'size', String(size)]);
  }

  static buildStreamDisplayUrl(songId: string, maxBitRate: number = 0): string {
    const params: string[] = ['id', songId];
    if (maxBitRate > 0) {
      params.push('maxBitRate', String(maxBitRate));
    }
    return AuthContext.buildMediaUrl('stream', params);
  }

  private static onEndpointChanged(to: EndpointType): void {
    for (let i: number = 0; i < MediaResourceService.activeStreams.length; i++) {
      MediaResourceService.activeStreams[i].migrate(to);
    }
  }

  /** 由 NetworkCoordinator 在通知播放管线之前调用，保证 URL 已切到新 endpoint */
  static migrateActiveStreams(to: EndpointType): void {
    MediaResourceService.onEndpointChanged(to);
  }

  private static removeStream(resource: StreamResource): void {
    const idx: number = MediaResourceService.activeStreams.indexOf(resource);
    if (idx >= 0) {
      MediaResourceService.activeStreams.splice(idx, 1);
    }
  }
}
