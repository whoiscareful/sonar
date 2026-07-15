import { Song } from '../../api/SubsonicTypes';
import { SubsonicClient } from '../../api/SubsonicClient';
import { Logger } from '../../common/Logger';
import { MusicCatalogRepository } from './MusicCatalogRepository';

const FAVORITE_REVISION_KEY: string = 'favoriteRevision';

/** Music Tag Web / Subsonic starred 状态的单一事实来源。 */
export class FavoriteSyncService {
  private static instance: FavoriteSyncService | null = null;
  private readonly favoriteIds: Set<string> = new Set<string>();
  private readonly pendingIds: Set<string> = new Set<string>();
  private readonly catalog: MusicCatalogRepository = MusicCatalogRepository.getInstance();
  private readonly client: SubsonicClient = SubsonicClient.getInstance();

  private constructor() {
  }

  static getInstance(): FavoriteSyncService {
    if (FavoriteSyncService.instance === null) {
      FavoriteSyncService.instance = new FavoriteSyncService();
    }
    return FavoriteSyncService.instance;
  }

  isFavorite(songId: string, starred?: string): boolean {
    if (this.favoriteIds.has(songId)) {
      return true;
    }
    return starred !== undefined && starred.length > 0;
  }

  isPending(songId: string): boolean {
    return this.pendingIds.has(songId);
  }

  async refreshAll(): Promise<Song[]> {
    const songs: Song[] = await this.catalog.favoriteSongs();
    this.favoriteIds.clear();
    for (let i: number = 0; i < songs.length; i++) {
      this.favoriteIds.add(songs[i].id);
      if (songs[i].starred === undefined || songs[i].starred?.length === 0) {
        songs[i].starred = new Date().toISOString();
      }
    }
    this.publish();
    return songs;
  }

  async refreshSong(songId: string): Promise<boolean> {
    const song: Song = await this.catalog.song(songId);
    const favorite: boolean = song.starred !== undefined && song.starred.length > 0;
    this.applyLocal(songId, favorite);
    this.publish();
    return favorite;
  }

  async setFavorite(songId: string, favorite: boolean): Promise<void> {
    if (songId.length === 0 || this.pendingIds.has(songId)) {
      if (this.pendingIds.has(songId)) {
        throw new Error('喜爱状态正在同步');
      }
      return;
    }
    const previous: boolean = this.favoriteIds.has(songId);
    this.pendingIds.add(songId);
    this.applyLocal(songId, favorite);
    this.publish();
    try {
      await this.client.setSongStarred(songId, favorite);
      const serverSongs: Song[] = await this.client.getStarredSongs();
      const serverHasFavorite: boolean = serverSongs.some((song: Song) => song.id === songId);
      if (serverHasFavorite !== favorite) {
        throw new Error('服务端未确认喜爱状态，请稍后重试');
      }
      this.replaceFromServer(serverSongs);
    } catch (err) {
      const message: string = (err as Error).message;
      this.applyLocal(songId, previous);
      this.publish();
      Logger.warn('FavoriteSyncService', `sync failed for ${songId}: ${message}`);
      throw new Error(message);
    } finally {
      this.pendingIds.delete(songId);
      this.publish();
    }
  }

  async toggle(song: Song): Promise<boolean> {
    const favorite: boolean = !this.isFavorite(song.id, song.starred);
    await this.setFavorite(song.id, favorite);
    song.starred = favorite ? new Date().toISOString() : undefined;
    return favorite;
  }

  clear(): void {
    this.favoriteIds.clear();
    this.pendingIds.clear();
    this.publish();
  }

  private applyLocal(songId: string, favorite: boolean): void {
    if (favorite) {
      this.favoriteIds.add(songId);
    } else {
      this.favoriteIds.delete(songId);
    }
  }

  private replaceFromServer(songs: Song[]): void {
    this.favoriteIds.clear();
    for (let i: number = 0; i < songs.length; i++) {
      this.favoriteIds.add(songs[i].id);
    }
  }

  private publish(): void {
    const revision: number = AppStorage.get<number>(FAVORITE_REVISION_KEY) ?? 0;
    AppStorage.setOrCreate<number>(FAVORITE_REVISION_KEY, revision + 1);
  }
}
