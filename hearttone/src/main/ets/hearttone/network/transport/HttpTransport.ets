import { http } from '@kit.NetworkKit';
import { AuthStore, EndpointType } from '../../auth/AuthStore';
import { SubsonicApiError } from '../../api/SubsonicTypes';
import { Logger } from '../../common/Logger';
import { SubsonicResponseParser } from '../api/SubsonicResponseParser';
import { EndpointRouter } from '../routing/EndpointRouter';
import { CancelToken } from './CancelToken';
import { getHttpProfileConfig, HttpProfile } from './HttpProfiles';
import { FallbackRequest, StreamHandle, StreamOpenOptions } from './HttpTypes';

class HttpStreamHandle implements StreamHandle {
  private readonly destroyFn: () => void;

  constructor(destroyFn: () => void) {
    this.destroyFn = destroyFn;
  }

  destroy(): void {
    this.destroyFn();
  }
}

function AuthStoreHasLocal(): boolean {
  return AuthStore.getInstance().hasLocalServerUrl();
}

export class HttpTransport {
  static async requestJsonText(url: string, profile: HttpProfile,
    cancelToken?: CancelToken): Promise<string> {
    return await HttpTransport.executeTextRequest(url, profile, cancelToken);
  }

  static async requestBuffer(url: string, profile: HttpProfile = 'binarySmall',
    cancelToken?: CancelToken): Promise<ArrayBuffer> {
    return await HttpTransport.executeBufferRequest(url, profile, cancelToken);
  }

  static async probeRest(url: string, cancelToken?: CancelToken): Promise<void> {
    await HttpTransport.executeTextRequest(url, 'probe', cancelToken);
  }

  static async requestWithFallback(req: FallbackRequest): Promise<string> {
    const preferred: EndpointType = EndpointRouter.getActiveEndpoint();
    try {
      return await HttpTransport.executeTextRequest(req.buildUrl(preferred), req.profile, req.cancelToken);
    } catch (err) {
      const apiErr: SubsonicApiError = HttpTransport.asApiError(err);
      const canFallback: boolean =
        preferred === 'local' &&
        AuthStoreHasLocal() &&
        SubsonicResponseParser.shouldFallbackFromLocal(apiErr);
      if (!canFallback) {
        throw apiErr;
      }
      Logger.warn('HttpTransport', `local request failed, fallback remote in same promise: ${apiErr.message}`);
      await EndpointRouter.handBackToRemote('request_fallback');
      return await HttpTransport.executeTextRequest(req.buildUrl('remote'), req.profile, req.cancelToken);
    }
  }

  static async requestBufferWithFallback(req: FallbackRequest): Promise<ArrayBuffer> {
    const preferred: EndpointType = EndpointRouter.getActiveEndpoint();
    try {
      return await HttpTransport.executeBufferRequest(req.buildUrl(preferred), req.profile, req.cancelToken);
    } catch (err) {
      const apiErr: SubsonicApiError = HttpTransport.asApiError(err);
      const canFallback: boolean =
        preferred === 'local' &&
        AuthStoreHasLocal() &&
        SubsonicResponseParser.shouldFallbackFromLocal(apiErr);
      if (!canFallback) {
        throw apiErr;
      }
      Logger.warn('HttpTransport', `local buffer failed, fallback remote: ${apiErr.message}`);
      await EndpointRouter.handBackToRemote('request_fallback');
      return await HttpTransport.executeBufferRequest(req.buildUrl('remote'), req.profile, req.cancelToken);
    }
  }

  static openStream(opts: StreamOpenOptions): StreamHandle {
    const request = http.createHttp();
    let destroyed: boolean = false;
    const destroy = (): void => {
      if (destroyed) {
        return;
      }
      destroyed = true;
      opts.cancelToken.cancel();
      try {
        request.destroy();
      } catch (_err) {
      }
    };
    opts.cancelToken.onCancel(() => {
      destroy();
    });
    const headers: Record<string, string> = {
      'Accept': '*/*'
    };
    if (opts.byteOffset > 0) {
      headers['Range'] = `bytes=${opts.byteOffset}-`;
    }
    request.on('dataReceive', (data: ArrayBuffer) => {
      if (destroyed || opts.cancelToken.isCancelled) {
        return;
      }
      void opts.onChunk(data);
    });
    request.on('headersReceive', (header: Object) => {
      if (opts.onHeaders !== undefined) {
        const mapped: Record<string, string> = {};
        const entries: [string, Object][] = Object.entries(header);
        for (let i: number = 0; i < entries.length; i++) {
          mapped[entries[i][0]] = String(entries[i][1]);
        }
        opts.onHeaders(mapped);
      }
    });
    const profile = getHttpProfileConfig('binaryStream');
    request.requestInStream(opts.url, {
      method: http.RequestMethod.GET,
      header: headers,
      connectTimeout: profile.connectTimeoutMs,
      readTimeout: profile.readTimeoutMs
    }).then(() => {
      if (!destroyed) {
        opts.onComplete();
      }
    }).catch((err: Error) => {
      if (!destroyed) {
        opts.onError(err);
      }
    });
    return new HttpStreamHandle(destroy);
  }

  private static async executeTextRequest(url: string, profile: HttpProfile,
    cancelToken?: CancelToken): Promise<string> {
    const config = getHttpProfileConfig(profile);
    let attempt: number = 1;
    while (true) {
      HttpTransport.throwIfCancelled(cancelToken);
      try {
        return await HttpTransport.requestOnceText(url, profile, cancelToken);
      } catch (err) {
        const apiErr: SubsonicApiError = HttpTransport.asApiError(err);
        if (attempt >= config.maxAttemptsOnSameEndpoint ||
          !SubsonicResponseParser.isRetryableError(apiErr)) {
          throw apiErr;
        }
        Logger.warn('HttpTransport', `retry ${attempt}/${config.maxAttemptsOnSameEndpoint}: ${apiErr.message}`);
        attempt++;
      }
    }
  }

  private static async executeBufferRequest(url: string, profile: HttpProfile,
    cancelToken?: CancelToken): Promise<ArrayBuffer> {
    const config = getHttpProfileConfig(profile);
    let attempt: number = 1;
    while (true) {
      HttpTransport.throwIfCancelled(cancelToken);
      try {
        return await HttpTransport.requestOnceBuffer(url, profile, cancelToken);
      } catch (err) {
        const apiErr: SubsonicApiError = HttpTransport.asApiError(err);
        if (attempt >= config.maxAttemptsOnSameEndpoint ||
          !SubsonicResponseParser.isRetryableError(apiErr)) {
          throw apiErr;
        }
        Logger.warn('HttpTransport', `buffer retry ${attempt}/${config.maxAttemptsOnSameEndpoint}: ${apiErr.message}`);
        attempt++;
      }
    }
  }

  private static async requestOnceText(url: string, profile: HttpProfile,
    cancelToken?: CancelToken): Promise<string> {
    const config = getHttpProfileConfig(profile);
    const req = http.createHttp();
    let unregister: (() => void) | undefined;
    try {
      if (cancelToken !== undefined) {
        unregister = HttpTransport.bindCancel(req, cancelToken);
      }
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: config.connectTimeoutMs,
        readTimeout: config.readTimeoutMs
      });
      if (resp.responseCode !== http.ResponseCode.OK) {
        throw new SubsonicApiError(resp.responseCode, `HTTP ${resp.responseCode}`);
      }
      const text: string = resp.result as string;
      if (profile === 'probe') {
        SubsonicResponseParser.parseEnvelope(text);
      }
      return text;
    } catch (err) {
      if (err instanceof SubsonicApiError) {
        throw err;
      }
      throw new SubsonicApiError(0, (err as Error).message);
    } finally {
      if (unregister !== undefined) {
        unregister();
      }
      req.destroy();
    }
  }

  private static async requestOnceBuffer(url: string, profile: HttpProfile,
    cancelToken?: CancelToken): Promise<ArrayBuffer> {
    const config = getHttpProfileConfig(profile);
    const req = http.createHttp();
    let unregister: (() => void) | undefined;
    try {
      if (cancelToken !== undefined) {
        unregister = HttpTransport.bindCancel(req, cancelToken);
      }
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: config.connectTimeoutMs,
        readTimeout: config.readTimeoutMs
      });
      if (resp.responseCode !== http.ResponseCode.OK) {
        throw new SubsonicApiError(resp.responseCode, `HTTP ${resp.responseCode}`);
      }
      return resp.result as ArrayBuffer;
    } catch (err) {
      if (err instanceof SubsonicApiError) {
        throw err;
      }
      throw new SubsonicApiError(0, (err as Error).message);
    } finally {
      if (unregister !== undefined) {
        unregister();
      }
      req.destroy();
    }
  }

  private static bindCancel(req: http.HttpRequest, cancelToken: CancelToken): () => void {
    const handler = (): void => {
      try {
        req.destroy();
      } catch (_err) {
      }
    };
    cancelToken.onCancel(handler);
    return (): void => {
    };
  }

  private static throwIfCancelled(cancelToken?: CancelToken): void {
    if (cancelToken !== undefined && cancelToken.isCancelled) {
      throw new SubsonicApiError(0, 'Request cancelled');
    }
  }

  private static asApiError(err: Object): SubsonicApiError {
    if (err instanceof SubsonicApiError) {
      return err;
    }
    return new SubsonicApiError(0, (err as Error).message);
  }
}
