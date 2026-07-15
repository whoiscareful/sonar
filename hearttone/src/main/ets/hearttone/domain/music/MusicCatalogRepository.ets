import {
  AlbumDetailResponse,
  AlbumListResponse,
  ArtistsResponse,
  MusicListKind,
  SearchResponse,
  Song
} from '../../api/SubsonicTypes';
import { SubsonicClient } from '../../api/SubsonicClient';

/**
 * Subsonic 音乐目录域的唯一数据入口。
 * ViewModel 不再关心 REST 接口名称、鉴权参数或局域网/远程回退细节。
 */
export class MusicCatalogRepository {
  private static instance: MusicCatalogRepository | null = null;
  private readonly client: SubsonicClient = SubsonicClient.getInstance();

  private constructor() {
  }

  static getInstance(): MusicCatalogRepository {
    if (MusicCatalogRepository.instance === null) {
      MusicCatalogRepository.instance = new MusicCatalogRepository();
    }
    return MusicCatalogRepository.instance;
  }

  async artists(): Promise<ArtistsResponse> {
    return await this.client.getArtists();
  }

  async albumFeed(type: string, size: number, offset: number): Promise<AlbumListResponse> {
    return await this.client.getAlbumList2(type, size, offset);
  }

  async randomSongs(size: number): Promise<Song[]> {
    return await this.client.getRandomSongs(size);
  }

  async songsForKind(kind: MusicListKind, albumBatchSize: number, offset: number): Promise<Song[]> {
    return await this.client.getSongsViaAlbumList(kind, albumBatchSize, offset);
  }

  async favoriteSongs(): Promise<Song[]> {
    return await this.client.getStarredSongs();
  }

  async song(id: string): Promise<Song> {
    return await this.client.getSong(id);
  }

  async album(id: string): Promise<AlbumDetailResponse> {
    return await this.client.getAlbum(id);
  }

  async search(query: string, artistCount: number, albumCount: number,
    songCount: number): Promise<SearchResponse> {
    return await this.client.search3(query, artistCount, albumCount, songCount);
  }
}
