import { EndpointType, SavedAuth } from '../auth/AuthStore';
import {
  AlbumDetailResponse,
  AlbumListResponse,
  ArtistsResponse,
  MusicListKind,
  SearchResponse,
  Song,
  SubsonicEnvelope
} from './SubsonicTypes';
import { MediaResourceService } from '../network/media/MediaResourceService';
import { SubsonicApi } from '../network/api/SubsonicApi';
import { SubsonicUrlUtil } from '../network/api/SubsonicUrlUtil';

/** @deprecated 请使用 SubsonicApi；保留薄 facade 以兼容现有调用方。 */
export class SubsonicClient {
  private static instance: SubsonicClient | null = null;

  private constructor() {
  }

  static normalizeServerUrl(rawUrl: string): string {
    return SubsonicUrlUtil.normalizeServerUrl(rawUrl);
  }

  static toArray<T>(value: T | T[] | undefined): T[] {
    return SubsonicApi.toArray<T>(value);
  }

  static getInstance(): SubsonicClient {
    if (SubsonicClient.instance === null) {
      SubsonicClient.instance = new SubsonicClient();
    }
    return SubsonicClient.instance;
  }

  static configureRetryPolicy(_enableRetry: boolean, _maxAttempts: number = 3): void {
  }

  static async buildLoginAuth(remoteUrl: string, localUrl: string | undefined,
    username: string, password: string): Promise<SavedAuth> {
    return await SubsonicApi.buildLoginAuth(remoteUrl, localUrl, username, password);
  }

  async pingEndpoint(auth: SavedAuth, endpoint: EndpointType, _enableRetry: boolean = true): Promise<void> {
    await SubsonicApi.pingEndpoint(auth, endpoint);
  }

  async getArtists(): Promise<ArtistsResponse> {
    return await SubsonicApi.getArtists();
  }

  async getAlbumList2(type: string = 'newest', size: number = 60, offset: number = 0): Promise<AlbumListResponse> {
    return await SubsonicApi.getAlbumList2(type, size, offset);
  }

  async getRandomSongs(size: number = 100): Promise<Song[]> {
    return await SubsonicApi.getRandomSongs(size);
  }

  async getSongsViaAlbumList(type: MusicListKind, albumBatchSize: number,
    albumOffset: number): Promise<Song[]> {
    if (type === 'random') {
      return await SubsonicApi.getRandomSongs(100);
    }
    const albumType: string = type === 'frequent' ? 'frequent' :
      (type === 'recent' ? 'recent' : 'newest');
    return await SubsonicApi.getSongsViaAlbumList(albumType, albumBatchSize, albumOffset);
  }

  async getAlbum(id: string): Promise<AlbumDetailResponse> {
    return await SubsonicApi.getAlbum(id);
  }

  async getSong(id: string): Promise<Song> {
    return await SubsonicApi.getSong(id);
  }

  async search3(query: string, artistCount: number = 20,
    albumCount: number = 20, songCount: number = 20): Promise<SearchResponse> {
    return await SubsonicApi.search3(query, artistCount, albumCount, songCount);
  }

  getCoverArtUrl(coverArtId: string, size: number = 300): string {
    return MediaResourceService.buildCoverDisplayUrl(coverArtId, size);
  }

  getStreamUrl(songId: string, maxBitRate: number = 0): string {
    return MediaResourceService.buildStreamDisplayUrl(songId, maxBitRate);
  }

  getScrobbleUrl(_songId: string): string {
    return '';
  }

  async reportNowPlaying(songId: string, positionMs: number = 0): Promise<void> {
    await SubsonicApi.reportNowPlaying(songId, positionMs);
  }

  async submitScrobble(songId: string, listenedAtEpochMs: number = Date.now()): Promise<void> {
    await SubsonicApi.submitScrobble(songId, listenedAtEpochMs);
  }
}

export type { SubsonicEnvelope } from './SubsonicTypes';
