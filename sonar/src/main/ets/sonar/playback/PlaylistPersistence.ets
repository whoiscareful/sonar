import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Song } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { Logger } from '../common/Logger';

const STORE_NAME: string = 'sonar_playlist';
const KEY_SONGS_JSON: string = 'songs_json';
const KEY_CURRENT_INDEX: string = 'current_index';

interface PersistedSong {
  id: string;
  parent: string;
  isDir: boolean;
  title: string;
  album: string;
  artist: string;
  coverArt?: string;
  size: number;
  duration: number;
}

export interface RestoredPlaylist {
  songs: Song[];
  currentIndex: number;
}

export class PlaylistPersistence {
  private static instance: PlaylistPersistence | null = null;
  private store: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private persistTimerId: number = -1;
  private pendingSongs: Song[] = [];
  private pendingIndex: number = -1;

  private constructor() {
  }

  static getInstance(): PlaylistPersistence {
    if (PlaylistPersistence.instance === null) {
      PlaylistPersistence.instance = new PlaylistPersistence();
    }
    return PlaylistPersistence.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store !== null) {
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
    } catch (err) {
      Logger.warn('PlaylistPersistence', `init failed: ${(err as Error).message}`);
    }
  }

  async ensureReady(): Promise<void> {
    if (this.store !== null) {
      return;
    }
    if (this.context === null) {
      return;
    }
    await this.init(this.context);
  }

  scheduleSave(songs: Song[], currentIndex: number): void {
    this.pendingSongs = songs;
    this.pendingIndex = currentIndex;
    if (this.persistTimerId >= 0) {
      clearTimeout(this.persistTimerId);
    }
    this.persistTimerId = setTimeout(() => {
      this.persistTimerId = -1;
      void this.flushPending();
    }, 400);
  }

  async flushPending(): Promise<void> {
    await this.save(this.pendingSongs, this.pendingIndex);
  }

  async save(songs: Song[], currentIndex: number): Promise<void> {
    await this.ensureReady();
    if (this.store === null) {
      return;
    }
    try {
      const payload: PersistedSong[] = songs.map((song: Song) => PlaylistPersistence.toPersisted(song));
      await this.store.put(KEY_SONGS_JSON, JSON.stringify(payload));
      await this.store.put(KEY_CURRENT_INDEX, currentIndex);
      await this.store.flush();
    } catch (err) {
      Logger.warn('PlaylistPersistence', `save failed: ${(err as Error).message}`);
    }
  }

  async load(): Promise<RestoredPlaylist | null> {
    await this.ensureReady();
    if (this.store === null) {
      return null;
    }
    try {
      const rawJson: string = (await this.store.get(KEY_SONGS_JSON, '[]')) as string;
      const currentIndex: number = (await this.store.get(KEY_CURRENT_INDEX, -1)) as number;
      const parsed: PersistedSong[] = JSON.parse(rawJson) as PersistedSong[];
      if (!Array.isArray(parsed) || parsed.length === 0) {
        return null;
      }
      const songs: Song[] = await PlaylistPersistence.hydrateSongs(parsed);
      if (songs.length === 0) {
        return null;
      }
      let safeIndex: number = currentIndex;
      if (safeIndex < 0 || safeIndex >= songs.length) {
        safeIndex = 0;
      }
      return { songs: songs, currentIndex: safeIndex };
    } catch (err) {
      Logger.warn('PlaylistPersistence', `load failed: ${(err as Error).message}`);
      return null;
    }
  }

  async clear(): Promise<void> {
    await this.ensureReady();
    if (this.store === null) {
      return;
    }
    try {
      await this.store.delete(KEY_SONGS_JSON);
      await this.store.delete(KEY_CURRENT_INDEX);
      await this.store.flush();
    } catch (err) {
      Logger.warn('PlaylistPersistence', `clear failed: ${(err as Error).message}`);
    }
  }

  private static toPersisted(song: Song): PersistedSong {
    return {
      id: song.id,
      parent: song.parent,
      isDir: song.isDir,
      title: song.title,
      album: song.album,
      artist: song.artist,
      coverArt: song.coverArt,
      size: song.size,
      duration: song.duration
    };
  }

  private static fromPersisted(item: PersistedSong): Song {
    return {
      id: item.id,
      parent: item.parent,
      isDir: item.isDir,
      title: item.title,
      album: item.album,
      artist: item.artist,
      coverArt: item.coverArt,
      size: item.size,
      duration: item.duration
    };
  }

  private static async hydrateSongs(stored: PersistedSong[]): Promise<Song[]> {
    const client: SubsonicClient = SubsonicClient.getInstance();
    const result: Song[] = [];
    for (let i: number = 0; i < stored.length; i++) {
      const fallback: Song = PlaylistPersistence.fromPersisted(stored[i]);
      if (fallback.id.length === 0) {
        continue;
      }
      try {
        const fresh: Song = await client.getSong(fallback.id);
        result.push(fresh);
      } catch (_err) {
        result.push(fallback);
      }
    }
    return result;
  }
}
