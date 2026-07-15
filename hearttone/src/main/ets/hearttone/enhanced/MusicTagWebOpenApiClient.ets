import { http } from '@kit.NetworkKit';
import { LyricsContainer } from '../api/SubsonicTypes';
import { AuthStore, EndpointType, SavedAuth } from '../auth/AuthStore';
import { Logger } from '../common/Logger';
import { EnhancedLyricsProvider } from '../domain/lyrics/LyricsRepository';
import { MusicTagWebHealth, MusicTagWebOpenApi, MusicTagWebStats } from './MusicTagWebOpenApi';
import { OpenApiCredentialStore } from './OpenApiCredentialStore';

interface HealthResponse {
  health?: string;
}

interface StatsResponse {
  health?: string;
  album_count?: string;
  track_count?: string;
  artist_count?: string;
  song_size?: string;
  song_duration?: string;
  now_playing?: string;
}

interface LyricsItemResponse {
  id?: string;
  title?: string;
  artist?: string;
  album?: string;
  lyrics?: string;
}

class LyricsSaveRequest {
  title: string = '';
  artist: string = '';
  album: string = '';
  lyrics: string = '';
  path?: string;
}

export class MusicTagWebOpenApiClient implements MusicTagWebOpenApi, EnhancedLyricsProvider {
  private static instance: MusicTagWebOpenApiClient | null = null;

  static getInstance(): MusicTagWebOpenApiClient {
    if (MusicTagWebOpenApiClient.instance === null) {
      MusicTagWebOpenApiClient.instance = new MusicTagWebOpenApiClient();
    }
    return MusicTagWebOpenApiClient.instance;
  }

  async health(): Promise<MusicTagWebHealth> {
    try {
      // 当前 Music Tag Web 服务端实现会对健康检查执行全局认证，
      // 即使接口文档将其标记为“无验证”，也需要携带 Bearer Token。
      const raw: string = await this.requestJson('/apigw/info/health/', true);
      const data: HealthResponse = JSON.parse(raw) as HealthResponse;
      const ok: boolean = data.health === 'ok';
      return { healthy: ok, message: data.health ?? 'unknown' };
    } catch (err) {
      return { healthy: false, message: (err as Error).message };
    }
  }

  async stats(username?: string, fields?: string): Promise<MusicTagWebStats> {
    return this.parseStats(await this.requestJson(this.statsPath(username, fields), true));
  }

  async verifyToken(token: string, username?: string, fields?: string): Promise<MusicTagWebStats> {
    const normalized: string = OpenApiCredentialStore.normalizeToken(token);
    if (normalized.length === 0) {
      throw new Error('请输入开放 API Token');
    }
    const raw: string = await this.requestJson(this.statsPath(username, fields), true,
      http.RequestMethod.GET, undefined, normalized);
    return this.parseStats(raw);
  }

  private statsPath(username?: string, fields?: string): string {
    const params: string[] = [];
    if (username !== undefined && username.length > 0) {
      params.push('username=' + encodeURIComponent(username));
    }
    if (fields !== undefined && fields.length > 0) {
      params.push('fields=' + encodeURIComponent(fields));
    }
    const suffix: string = params.length > 0 ? `?${params.join('&')}` : '';
    return `/apigw/info/${suffix}`;
  }

  private parseStats(raw: string): MusicTagWebStats {
    const data: StatsResponse = JSON.parse(raw) as StatsResponse;
    return {
      health: data.health,
      albumCount: data.album_count,
      trackCount: data.track_count,
      artistCount: data.artist_count,
      songSize: data.song_size,
      songDuration: data.song_duration,
      nowPlaying: data.now_playing
    };
  }

  async loadLyrics(_songId: string, artist: string, title: string, album: string): Promise<LyricsContainer | null> {
    const raw: string = await this.requestJson('/apigw/lyrics/?' + [
      'title=' + encodeURIComponent(title),
      'artist=' + encodeURIComponent(artist),
      'album=' + encodeURIComponent(album)
    ].join('&'), true);
    const items: LyricsItemResponse[] = JSON.parse(raw) as LyricsItemResponse[];
    if (items.length === 0) {
      return null;
    }
    const first: LyricsItemResponse = items[0];
    if (first.lyrics === undefined || first.lyrics.length === 0) {
      return null;
    }
    return {
      artist: first.artist ?? artist,
      title: first.title ?? title,
      value: first.lyrics
    };
  }

  async load(songId: string, artist: string, title: string, album: string): Promise<LyricsContainer | null> {
    return await this.loadLyrics(songId, artist, title, album);
  }

  async saveLyrics(_songId: string, artist: string, title: string, album: string,
    content: string, path?: string): Promise<void> {
    const body: LyricsSaveRequest = new LyricsSaveRequest();
    body.title = title;
    body.artist = artist;
    body.album = album;
    body.lyrics = content;
    if (path !== undefined && path.length > 0) {
      body.path = path;
    }
    await this.requestJson('/apigw/lyrics/', true, http.RequestMethod.POST, JSON.stringify(body));
  }

  async save(songId: string, artist: string, title: string, album: string, content: string): Promise<void> {
    await this.saveLyrics(songId, artist, title, album, content);
  }

  metadataDetailUrl(path: string): string {
    const auth: SavedAuth | null = AuthStore.getInstance().getCredentials();
    const baseUrl: string = auth === null ? '' : AuthStore.resolveEndpointUrl(auth, AuthStore.getInstance().getActiveEndpoint());
    if (baseUrl.length === 0) {
      return '';
    }
    return `${baseUrl}/#/detail?target=detail&path=${encodeURIComponent(path)}`;
  }

  async updateProfileAvatar(_fileName: string, _mimeType: string, _data: ArrayBuffer): Promise<string | null> {
    throw new Error('Music Tag Web 头像上传接口未在开放 API 中提供');
  }

  async updateProfileCover(_fileName: string, _mimeType: string, _data: ArrayBuffer): Promise<string | null> {
    throw new Error('Music Tag Web 封面上传接口未在开放 API 中提供');
  }

  private async requestJson(path: string, authRequired: boolean,
    method: http.RequestMethod = http.RequestMethod.GET, body?: string, tokenOverride?: string): Promise<string> {
    const auth: SavedAuth | null = AuthStore.getInstance().getCredentials();
    if (auth === null) {
      throw new Error('尚未登录服务器');
    }
    const active: EndpointType = AuthStore.getInstance().getActiveEndpoint();
    try {
      return await this.requestOnce(this.buildUrl(auth, active, path), authRequired, method, body, tokenOverride);
    } catch (err) {
      if (active === 'local') {
        Logger.warn('MusicTagWebOpenApiClient', `local request failed, fallback remote: ${(err as Error).message}`);
        return await this.requestOnce(this.buildUrl(auth, 'remote', path), authRequired, method, body, tokenOverride);
      }
      throw new Error((err as Error).message);
    }
  }

  private buildUrl(auth: SavedAuth, endpoint: EndpointType, path: string): string {
    const baseUrl: string = AuthStore.resolveEndpointUrl(auth, endpoint);
    if (path.startsWith('/')) {
      return `${baseUrl}${path}`;
    }
    return `${baseUrl}/${path}`;
  }

  private async requestOnce(url: string, authRequired: boolean,
    method: http.RequestMethod, body?: string, tokenOverride?: string): Promise<string> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };
      if (authRequired) {
        const token: string = tokenOverride !== undefined ?
          OpenApiCredentialStore.normalizeToken(tokenOverride) : await OpenApiCredentialStore.getToken();
        if (token.length === 0) {
          throw new Error('请先配置 Music Tag Web 开放 API Token');
        }
        headers['Authorization'] = `Bearer ${token}`;
      }
      const response = await req.request(url, {
        method,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 12000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        if (response.responseCode === 401) {
          throw new Error('HTTP 401：开放 API Token 无效或已过期，请在 Music Tag Web 重新生成 Bearer Token');
        }
        throw new Error(`HTTP ${response.responseCode}`);
      }
      return response.result as string;
    } finally {
      req.destroy();
    }
  }
}
