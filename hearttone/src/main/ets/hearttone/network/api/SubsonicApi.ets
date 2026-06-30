import {
  Album,
  AlbumDetailResponse,
  AlbumListResponse,
  Artist,
  ArtistIndex,
  ArtistsResponse,
  LyricsResponse,
  RandomSongsResponse,
  SearchResponse,
  Song,
  SongDetailResponse,
  SubsonicApiError,
  SubsonicEnvelope
} from '../../api/SubsonicTypes';
import { EndpointType, SavedAuth } from '../../auth/AuthStore';
import { Logger } from '../../common/Logger';
import { RandomUtil } from '../../crypto/RandomUtil';
import { Md5Util } from '../../crypto/Md5Util';
import { AuthContext } from '../auth/AuthContext';
import { SubsonicResponseParser } from './SubsonicResponseParser';
import { SubsonicUrlUtil } from './SubsonicUrlUtil';
import { HttpTransport } from '../transport/HttpTransport';
import { EndpointRouter } from '../routing/EndpointRouter';

interface ArtistIndexContainer {
  index?: ArtistIndex[] | ArtistIndex;
}

interface SingleOrArrayArtistIndex {
  name?: string;
  artist?: Artist[] | Artist;
}

export class SubsonicApi {
  static toArray<T>(value: T | T[] | undefined): T[] {
    if (value === undefined) {
      return [];
    }
    if (Array.isArray(value)) {
      return value;
    }
    return [value];
  }

  static async buildLoginAuth(remoteUrl: string, localUrl: string | undefined,
    username: string, password: string): Promise<SavedAuth> {
    const salt: string = RandomUtil.generateSalt();
    const token: string = await Md5Util.md5Hex(password + salt);
    return {
      remoteServerUrl: SubsonicUrlUtil.normalizeServerUrl(remoteUrl),
      localServerUrl: localUrl !== undefined ? SubsonicUrlUtil.normalizeServerUrl(localUrl) : undefined,
      activeEndpoint: 'remote',
      username,
      salt,
      token,
      authMode: 'subsonicToken'
    };
  }

  static async pingEndpoint(auth: SavedAuth, endpoint: EndpointType): Promise<void> {
    const url: string = AuthContext.buildRestUrl('ping.view', [], auth, endpoint);
    await HttpTransport.probeRest(url);
  }

  private static async requestEnvelope<T extends SubsonicEnvelope>(api: string,
    extraParams: string[] = []): Promise<T> {
    const text: string = await HttpTransport.requestWithFallback({
      buildUrl: (ep: EndpointType): string => AuthContext.buildRestUrl(api, extraParams, undefined, ep),
      profile: 'json'
    });
    return SubsonicResponseParser.parseEnvelopeAsync<T>(text);
  }

  static async getArtists(): Promise<ArtistsResponse> {
    const resp: ArtistsResponse = await SubsonicApi.requestEnvelope<ArtistsResponse>('getArtists.view');
    const artistsBox: ArtistIndexContainer = resp.artists as ArtistIndexContainer;
    const indexValue: ArtistIndex[] | ArtistIndex | undefined = artistsBox.index;
    const normalizedIndex: ArtistIndex[] = SubsonicApi.toArray<ArtistIndex>(indexValue);
    for (let i: number = 0; i < normalizedIndex.length; i++) {
      const item: SingleOrArrayArtistIndex = normalizedIndex[i] as SingleOrArrayArtistIndex;
      const artists: Artist[] | Artist | undefined = item.artist;
      item.artist = SubsonicApi.toArray<Artist>(artists);
      if (item.name === undefined) {
        item.name = '';
      }
    }
    resp.artists.index = normalizedIndex;
    return resp;
  }

  static async getAlbumList2(type: string = 'newest', size: number = 60,
    offset: number = 0): Promise<AlbumListResponse> {
    const resp: AlbumListResponse = await SubsonicApi.requestEnvelope<AlbumListResponse>('getAlbumList2.view', [
      'type', type, 'size', String(size), 'offset', String(offset)
    ]);
    const rawAlbums: Album[] | Album | undefined = resp.albumList2.album as Album[] | Album | undefined;
    resp.albumList2.album = SubsonicApi.toArray<Album>(rawAlbums);
    return resp;
  }

  static async getRandomSongs(size: number = 100): Promise<Song[]> {
    const resp: RandomSongsResponse =
      await SubsonicApi.requestEnvelope<RandomSongsResponse>('getRandomSongs.view', [
        'size', String(size)
      ]);
    const rawSongs: Song[] | Song | undefined = resp.randomSongs?.song as Song[] | Song | undefined;
    return SubsonicApi.toArray<Song>(rawSongs);
  }

  /** 通过 getAlbumList2 + getAlbum 展开为歌曲列表（frequent / recent / newest） */
  static async getSongsViaAlbumList(type: string, albumBatchSize: number,
    albumOffset: number): Promise<Song[]> {
    const resp: AlbumListResponse = await SubsonicApi.getAlbumList2(type, albumBatchSize, albumOffset);
    const albums: Album[] = resp.albumList2.album ?? [];
    if (albums.length === 0) {
      return [];
    }
    const songLists: Song[][] = await Promise.all(albums.map(async (album: Album) => {
      const detail: AlbumDetailResponse = await SubsonicApi.getAlbum(album.id);
      const songs: Song[] = detail.album.song ?? [];
      const albumCover: string = album.coverArt ?? detail.album.coverArt ?? '';
      for (let i: number = 0; i < songs.length; i++) {
        const songCover: string | undefined = songs[i].coverArt;
        if (songCover === undefined || songCover.length === 0) {
          songs[i].coverArt = albumCover.length > 0 ? albumCover : songCover;
        }
      }
      return songs;
    }));
    const merged: Song[] = [];
    const seenIds: Set<string> = new Set<string>();
    for (let a: number = 0; a < songLists.length; a++) {
      const batch: Song[] = songLists[a];
      for (let s: number = 0; s < batch.length; s++) {
        const song: Song = batch[s];
        if (!seenIds.has(song.id)) {
          seenIds.add(song.id);
          merged.push(song);
        }
      }
    }
    if (type === 'frequent') {
      merged.sort((a: Song, b: Song) => {
        const pa: number = a.playCount ?? 0;
        const pb: number = b.playCount ?? 0;
        return pb - pa;
      });
    }
    return merged;
  }

  static async getAlbum(id: string): Promise<AlbumDetailResponse> {
    const resp: AlbumDetailResponse =
      await SubsonicApi.requestEnvelope<AlbumDetailResponse>('getAlbum.view', ['id', id]);
    const rawSongs: Song[] | Song | undefined = resp.album.song as Song[] | Song | undefined;
    resp.album.song = SubsonicApi.toArray<Song>(rawSongs);
    return resp;
  }

  static async getSong(id: string): Promise<Song> {
    const resp: SongDetailResponse =
      await SubsonicApi.requestEnvelope<SongDetailResponse>('getSong.view', ['id', id]);
    return resp.song;
  }

  static async search3(query: string, artistCount: number = 20,
    albumCount: number = 20, songCount: number = 20): Promise<SearchResponse> {
    const resp: SearchResponse = await SubsonicApi.requestEnvelope<SearchResponse>('search3.view', [
      'query', query,
      'artistCount', String(artistCount),
      'albumCount', String(albumCount),
      'songCount', String(songCount)
    ]);
    if (resp.searchResult3 !== undefined) {
      resp.searchResult3.artist = SubsonicApi.toArray(resp.searchResult3.artist);
      resp.searchResult3.album = SubsonicApi.toArray(resp.searchResult3.album);
      resp.searchResult3.song = SubsonicApi.toArray(resp.searchResult3.song);
    }
    return resp;
  }

  static async reportNowPlaying(songId: string, positionMs: number = 0): Promise<void> {
    const positionSec: number = SubsonicApi.normalizePositionSeconds(positionMs);
    const params: string[] = ['id', songId, 'submission', 'false', 'time', '0'];
    if (positionSec > 0) {
      params.push('position', String(positionSec));
    }
    Logger.debug('SubsonicApi', `scrobble nowPlaying id=${songId} positionSec=${positionSec}`);
    try {
      await SubsonicApi.requestEnvelope<SubsonicEnvelope>('scrobble.view', params);
    } catch (err) {
      if (positionSec <= 0) {
        throw new Error((err as Error).message);
      }
      Logger.warn('SubsonicApi',
        `scrobble nowPlaying with position failed, fallback standard call: ${(err as Error).message}`);
      await SubsonicApi.requestEnvelope<SubsonicEnvelope>('scrobble.view', [
        'id', songId, 'submission', 'false', 'time', '0'
      ]);
    }
  }

  static async submitScrobble(songId: string, listenedAtEpochMs: number = Date.now()): Promise<void> {
    const normalizedEpochMs: number = SubsonicApi.normalizeEpochMs(listenedAtEpochMs);
    Logger.debug('SubsonicApi', `scrobble submission id=${songId} time=${normalizedEpochMs}`);
    await SubsonicApi.requestEnvelope<SubsonicEnvelope>('scrobble.view', [
      'id', songId, 'submission', 'true', 'time', String(normalizedEpochMs)
    ]);
  }

  static async validateLoginRemote(auth: SavedAuth): Promise<void> {
    await EndpointRouter.validateRemoteReachable(auth);
  }

  /**
   * 获取歌词
   * Subsonic getLyrics 接口
   * @param artist 歌手名
   * @param title 歌曲名
   * @returns 歌词响应，可能包含结构化歌词或 LRC 格式文本
   */
  static async getLyrics(artist: string, title: string): Promise<LyricsResponse> {
    const params: string[] = [];
    if (artist.length > 0) {
      params.push('artist', artist);
    }
    if (title.length > 0) {
      params.push('title', title);
    }
    const resp: LyricsResponse =
      await SubsonicApi.requestEnvelope<LyricsResponse>('getLyrics.view', params);
    return resp;
  }

  private static normalizeEpochMs(value: number): number {
    if (!Number.isFinite(value) || value <= 0) {
      return Date.now();
    }
    return Math.floor(value);
  }

  private static normalizePositionSeconds(positionMs: number): number {
    if (!Number.isFinite(positionMs) || positionMs <= 0) {
      return 0;
    }
    return Math.floor(positionMs / 1000);
  }
}
