import { Song } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { Logger } from '../common/Logger';

const MAX_ENTRIES: number = 400;
const FETCH_CONCURRENCY: number = 6;

/** 歌曲元数据唯一内存缓存；miss 时经 Subsonic getSong 回源。 */
export class SongMetadataCache {
  /** Map 插入序即 LRU 序：touch 为 delete 后重插末尾 */
  private static cache: Map<string, Song> = new Map<string, Song>();

  static put(song: Song): void {
    if (song.id.length === 0) {
      return;
    }
    SongMetadataCache.cache.delete(song.id);
    SongMetadataCache.cache.set(song.id, song);
    SongMetadataCache.evictIfNeeded();
  }

  static async get(songId: string): Promise<Song | null> {
    if (songId.length === 0) {
      return null;
    }
    const cached: Song | undefined = SongMetadataCache.cache.get(songId);
    if (cached !== undefined) {
      SongMetadataCache.touch(songId, cached);
      return cached;
    }
    try {
      const song: Song = await SubsonicClient.getInstance().getSong(songId);
      SongMetadataCache.put(song);
      return song;
    } catch (err) {
      Logger.warn('SongMetadataCache', `getSong failed id=${songId}: ${(err as Error).message}`);
      return null;
    }
  }

  static async getMany(songIds: string[]): Promise<Song[]> {
    const result: Song[] = [];
    for (let start: number = 0; start < songIds.length; start += FETCH_CONCURRENCY) {
      const chunkEnd: number = Math.min(start + FETCH_CONCURRENCY, songIds.length);
      const chunkPromises: Promise<Song | null>[] = [];
      for (let i: number = start; i < chunkEnd; i++) {
        chunkPromises.push(SongMetadataCache.get(songIds[i]));
      }
      const chunkResults: (Song | null)[] = await Promise.all(chunkPromises);
      for (let i: number = 0; i < chunkResults.length; i++) {
        const song: Song | null = chunkResults[i];
        if (song !== null) {
          result.push(song);
        }
      }
    }
    return result;
  }

  static invalidate(songId: string): void {
    SongMetadataCache.cache.delete(songId);
  }

  static clear(): void {
    SongMetadataCache.cache.clear();
  }

  private static touch(songId: string, song: Song): void {
    SongMetadataCache.cache.delete(songId);
    SongMetadataCache.cache.set(songId, song);
  }

  private static evictIfNeeded(): void {
    while (SongMetadataCache.cache.size > MAX_ENTRIES) {
      const oldest: IteratorResult<string> = SongMetadataCache.cache.keys().next();
      if (oldest.done || oldest.value === undefined) {
        break;
      }
      SongMetadataCache.cache.delete(oldest.value);
    }
  }
}
