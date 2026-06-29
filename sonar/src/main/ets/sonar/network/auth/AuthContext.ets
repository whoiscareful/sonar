import { AuthStore, EndpointType, SavedAuth } from '../../auth/AuthStore';
import { SubsonicApiError } from '../../api/SubsonicTypes';
import { SubsonicUrlUtil } from '../api/SubsonicUrlUtil';

const API_VERSION: string = '1.16.1';
const CLIENT_NAME: string = 'sonar';

export type MediaUrlKind = 'stream' | 'getCoverArt';

export class AuthContext {
  static getCredentials(): SavedAuth | null {
    return AuthStore.getInstance().getCredentials();
  }

  static resolveActiveEndpoint(explicit?: EndpointType): EndpointType {
    if (explicit !== undefined) {
      return explicit;
    }
    return AuthStore.getInstance().getActiveEndpoint();
  }

  static buildRestUrl(api: string, extraParams: string[] = [],
    auth?: SavedAuth, targetEndpoint?: EndpointType): string {
    return AuthContext.buildMediaPathUrl(api, extraParams, auth, targetEndpoint);
  }

  static buildMediaUrl(kind: MediaUrlKind, extraParams: string[] = [],
    auth?: SavedAuth, targetEndpoint?: EndpointType): string {
    const endpointName: string = kind === 'stream' ? 'stream.view' : 'getCoverArt.view';
    return AuthContext.buildMediaPathUrl(endpointName, extraParams, auth, targetEndpoint);
  }

  private static buildMediaPathUrl(endpoint: string, extraParams: string[] = [],
    auth?: SavedAuth, targetEndpoint?: EndpointType): string {
    const a: SavedAuth | null = auth ?? AuthStore.getInstance().getCredentials();
    if (a === null) {
      throw new SubsonicApiError(-3, 'Not logged in');
    }
    const resolvedEndpoint: EndpointType = targetEndpoint ?? AuthContext.resolveActiveEndpoint();
    const baseSource: string = AuthStore.resolveEndpointUrl(a, resolvedEndpoint);
    const base: string = SubsonicUrlUtil.normalizeServerUrl(baseSource);
    const isBinaryMedia: boolean = endpoint === 'stream.view' || endpoint === 'getCoverArt.view';
    const allParams: string[] = [
      'u=' + encodeURIComponent(a.username),
      'v=' + encodeURIComponent(API_VERSION),
      'c=' + encodeURIComponent(CLIENT_NAME),
      't=' + encodeURIComponent(a.token),
      's=' + encodeURIComponent(a.salt)
    ];
    if (!isBinaryMedia) {
      allParams.push('f=json');
    }
    if (a.authMode !== undefined && a.authMode !== 'subsonicToken') {
      throw new SubsonicApiError(-4, `Unsupported auth mode: ${a.authMode}`);
    }
    for (let i: number = 0; i < extraParams.length; i += 2) {
      const k: string = encodeURIComponent(extraParams[i]);
      const v: string = encodeURIComponent(extraParams[i + 1]);
      allParams.push(k + '=' + v);
    }
    return `${base}/rest/${endpoint}?${allParams.join('&')}`;
  }
}
