import { CancelToken } from './CancelToken';
import { HttpProfile } from './HttpProfiles';
import { EndpointType } from '../../auth/AuthStore';

export interface FallbackRequest {
  buildUrl: (endpoint: EndpointType) => string;
  profile: HttpProfile;
  cancelToken?: CancelToken;
}

export interface StreamOpenOptions {
  url: string;
  byteOffset: number;
  cancelToken: CancelToken;
  onHeaders?: (headers: Record<string, string>) => void;
  onChunk: (chunk: ArrayBuffer) => void | Promise<void>;
  onComplete: () => void;
  onError: (err: Error) => void;
}

export interface StreamHandle {
  destroy: () => void;
}
