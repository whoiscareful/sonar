import { EndpointType } from '../../auth/AuthStore';
import { AuthContext } from '../auth/AuthContext';
import { CancelToken } from '../transport/CancelToken';

export interface StreamRequestSpec {
  url: string;
  headers: Record<string, string>;
}

export class StreamResource {
  readonly songId: string;
  private cancelTokenRef: CancelToken;
  byteOffset: number;
  /** Subsonic stream.view offset（毫秒），用于切网续播，避免 AVPlayer 远程 seek 超时 */
  timeOffsetMs: number;
  private endpoint: EndpointType;
  private readonly maxBitRate: number;

  constructor(songId: string, endpoint: EndpointType, byteOffset: number, maxBitRate: number,
    cancelToken: CancelToken, timeOffsetMs: number = 0) {
    this.songId = songId;
    this.endpoint = endpoint;
    this.byteOffset = byteOffset;
    this.timeOffsetMs = timeOffsetMs;
    this.maxBitRate = maxBitRate;
    this.cancelTokenRef = cancelToken;
  }

  get cancelToken(): CancelToken {
    return this.cancelTokenRef;
  }

  /** Fetch 取消后换新 token，同曲目续拉 */
  renewCancelToken(): CancelToken {
    this.cancelTokenRef = new CancelToken();
    return this.cancelTokenRef;
  }

  getEndpoint(): EndpointType {
    return this.endpoint;
  }

  resolveRequest(): StreamRequestSpec {
    const params: string[] = ['id', this.songId];
    if (this.maxBitRate > 0) {
      params.push('maxBitRate', String(this.maxBitRate));
    }
    if (this.timeOffsetMs > 0) {
      params.push('offset', String(this.timeOffsetMs));
    }
    const url: string = AuthContext.buildMediaUrl('stream', params, undefined, this.endpoint);
    const headers: Record<string, string> = {};
    if (this.byteOffset > 0) {
      headers['Range'] = `bytes=${this.byteOffset}-`;
    }
    const spec: StreamRequestSpec = { url: url, headers: headers };
    return spec;
  }

  migrate(newEndpoint: EndpointType): void {
    this.endpoint = newEndpoint;
  }
}
