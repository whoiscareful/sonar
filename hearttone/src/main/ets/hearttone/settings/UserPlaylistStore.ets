import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Song } from '../api/SubsonicTypes';
import { AuthStore } from '../auth/AuthStore';
import { Logger } from '../common/Logger';
import { SubsonicUrlUtil } from '../network/api/SubsonicUrlUtil';

const STORE_NAME: string = 'hearttone_user_playlists';
const KEY_PREFIX: string = 'playlists_';

export interface UserPlaylist {
  id: string;
  name: string;
  description: string;
  songs: Song[];
  createdAt: number;
  updatedAt: number;
}

export interface UserPlaylistTransferResult {
  added: number;
  removed: number;
}

export class UserPlaylistStore {
  private static instance: UserPlaylistStore | null = null;
  private store: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private loadedAccountKey: string = '';
  private playlists: UserPlaylist[] = [];

  private constructor() {
  }

  static getInstance(): UserPlaylistStore {
    if (UserPlaylistStore.instance === null) {
      UserPlaylistStore.instance = new UserPlaylistStore();
    }
    return UserPlaylistStore.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store === null) {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
    }
    await this.ensureAccountLoaded();
  }

  async ensureReady(): Promise<void> {
    if (this.store === null && this.context !== null) {
      await this.init(this.context);
      return;
    }
    await this.ensureAccountLoaded();
  }

  list(): UserPlaylist[] {
    const result: UserPlaylist[] = [];
    for (let i: number = 0; i < this.playlists.length; i++) {
      result.push(UserPlaylistStore.copyPlaylist(this.playlists[i]));
    }
    return result;
  }

  get(id: string): UserPlaylist | null {
    const playlist: UserPlaylist | undefined = this.playlists.find(
      (item: UserPlaylist) => item.id === id);
    return playlist === undefined ? null : UserPlaylistStore.copyPlaylist(playlist);
  }

  async create(name: string, songs: Song[]): Promise<UserPlaylist> {
    await this.ensureReady();
    const now: number = Date.now();
    const playlist: UserPlaylist = {
      id: `playlist_${now}_${this.playlists.length}`,
      name: name.trim().length > 0 ? name.trim() : `新歌单 ${this.playlists.length + 1}`,
      description: '',
      songs: UserPlaylistStore.deduplicateSongs(songs),
      createdAt: now,
      updatedAt: now
    };
    this.playlists = [playlist, ...this.playlists];
    await this.persist();
    this.publishRevision();
    return UserPlaylistStore.copyPlaylist(playlist);
  }

  async remove(id: string): Promise<boolean> {
    await this.ensureReady();
    const before: number = this.playlists.length;
    this.playlists = this.playlists.filter((playlist: UserPlaylist) => playlist.id !== id);
    if (this.playlists.length === before) {
      return false;
    }
    await this.persist();
    this.publishRevision();
    return true;
  }

  async removeMany(ids: string[]): Promise<number> {
    await this.ensureReady();
    const selectedIds: Set<string> = new Set<string>(ids);
    const before: number = this.playlists.length;
    this.playlists = this.playlists.filter(
      (playlist: UserPlaylist) => !selectedIds.has(playlist.id));
    const removed: number = before - this.playlists.length;
    if (removed > 0) {
      await this.persist();
      this.publishRevision();
    }
    return removed;
  }

  async updateDetails(id: string, name: string, description: string): Promise<boolean> {
    await this.ensureReady();
    const playlist: UserPlaylist | undefined = this.playlists.find(
      (item: UserPlaylist) => item.id === id);
    if (playlist === undefined) {
      return false;
    }
    const normalizedName: string = name.trim();
    if (normalizedName.length === 0) {
      throw new Error('歌单名称不能为空');
    }
    playlist.name = normalizedName;
    playlist.description = description.trim();
    playlist.updatedAt = Date.now();
    await this.persist();
    this.publishRevision();
    return true;
  }

  async addSongs(id: string, songs: Song[]): Promise<number> {
    await this.ensureReady();
    let targetIndex: number = -1;
    for (let i: number = 0; i < this.playlists.length; i++) {
      if (this.playlists[i].id === id) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex < 0) {
      return 0;
    }
    const playlist: UserPlaylist = this.playlists[targetIndex];
    const merged: Song[] = UserPlaylistStore.deduplicateSongs(playlist.songs.concat(songs));
    const added: number = merged.length - playlist.songs.length;
    if (added <= 0) {
      return 0;
    }
    playlist.songs = merged;
    playlist.updatedAt = Date.now();
    await this.persist();
    this.publishRevision();
    return added;
  }

  async removeSongs(id: string, songIds: string[]): Promise<number> {
    await this.ensureReady();
    const playlist: UserPlaylist | undefined = this.playlists.find(
      (item: UserPlaylist) => item.id === id);
    if (playlist === undefined) {
      return 0;
    }
    const selectedIds: Set<string> = new Set<string>(songIds);
    const before: number = playlist.songs.length;
    playlist.songs = playlist.songs.filter((song: Song) => !selectedIds.has(song.id));
    const removed: number = before - playlist.songs.length;
    if (removed > 0) {
      playlist.updatedAt = Date.now();
      await this.persist();
      this.publishRevision();
    }
    return removed;
  }

  async deduplicate(id: string): Promise<number> {
    await this.ensureReady();
    const playlist: UserPlaylist | undefined = this.playlists.find(
      (item: UserPlaylist) => item.id === id);
    if (playlist === undefined) {
      return 0;
    }
    const before: number = playlist.songs.length;
    playlist.songs = UserPlaylistStore.deduplicateSongs(playlist.songs);
    const removed: number = before - playlist.songs.length;
    if (removed > 0) {
      playlist.updatedAt = Date.now();
      await this.persist();
      this.publishRevision();
    }
    return removed;
  }

  async transferSongs(
    sourcePlaylistId: string,
    targetPlaylistId: string,
    songIds: string[],
    move: boolean
  ): Promise<UserPlaylistTransferResult> {
    await this.ensureReady();
    if (sourcePlaylistId === targetPlaylistId) {
      return { added: 0, removed: 0 };
    }
    const source: UserPlaylist | undefined = this.playlists.find(
      (item: UserPlaylist) => item.id === sourcePlaylistId);
    const target: UserPlaylist | undefined = this.playlists.find(
      (item: UserPlaylist) => item.id === targetPlaylistId);
    if (source === undefined || target === undefined) {
      throw new Error('源歌单或目标歌单不存在');
    }
    const selectedIds: Set<string> = new Set<string>(songIds);
    const selectedSongs: Song[] = source.songs.filter((song: Song) => selectedIds.has(song.id));
    const beforeTarget: number = target.songs.length;
    target.songs = UserPlaylistStore.deduplicateSongs(target.songs.concat(selectedSongs));
    const added: number = target.songs.length - beforeTarget;
    let removed: number = 0;
    if (move) {
      const beforeSource: number = source.songs.length;
      source.songs = source.songs.filter((song: Song) => !selectedIds.has(song.id));
      removed = beforeSource - source.songs.length;
    }
    if (added > 0 || removed > 0) {
      const now: number = Date.now();
      target.updatedAt = now;
      if (move) {
        source.updatedAt = now;
      }
      await this.persist();
      this.publishRevision();
    }
    return { added: added, removed: removed };
  }

  async restore(playlists: UserPlaylist[], replaceExisting: boolean): Promise<void> {
    await this.ensureReady();
    const incoming: UserPlaylist[] = [];
    const incomingIds: Set<string> = new Set<string>();
    for (let i: number = 0; i < playlists.length; i++) {
      const playlist: UserPlaylist = playlists[i];
      if (playlist.id.length === 0 || incomingIds.has(playlist.id)) {
        continue;
      }
      incomingIds.add(playlist.id);
      incoming.push(UserPlaylistStore.copyPlaylist(playlist));
    }
    if (replaceExisting) {
      this.playlists = incoming;
    } else {
      const merged: UserPlaylist[] = incoming;
      for (let i: number = 0; i < this.playlists.length; i++) {
        const current: UserPlaylist = this.playlists[i];
        if (!incomingIds.has(current.id)) {
          merged.push(UserPlaylistStore.copyPlaylist(current));
        }
      }
      this.playlists = merged;
    }
    await this.persist();
    this.publishRevision();
  }

  async clearAllData(): Promise<void> {
    await this.ensureReady();
    this.playlists = [];
    if (this.store !== null && this.loadedAccountKey.length > 0) {
      await this.store.delete(`${KEY_PREFIX}${this.loadedAccountKey}`);
      await this.store.flush();
    }
    this.publishRevision();
  }

  clearMemory(): void {
    this.playlists = [];
    this.loadedAccountKey = '';
    this.publishRevision();
  }

  private async ensureAccountLoaded(): Promise<void> {
    const accountKey: string = UserPlaylistStore.computeAccountKey();
    if (accountKey === this.loadedAccountKey) {
      return;
    }
    this.loadedAccountKey = accountKey;
    this.playlists = [];
    if (this.store === null || accountKey.length === 0) {
      this.publishRevision();
      return;
    }
    try {
      const raw: string = (await this.store.get(`${KEY_PREFIX}${accountKey}`, '[]')) as string;
      const parsed: UserPlaylist[] = JSON.parse(raw) as UserPlaylist[];
      if (!Array.isArray(parsed)) {
        return;
      }
      for (let i: number = 0; i < parsed.length; i++) {
        const playlist: UserPlaylist = parsed[i];
        if (playlist.id !== undefined && playlist.id.length > 0 && playlist.name !== undefined &&
          Array.isArray(playlist.songs)) {
          this.playlists.push({
            id: playlist.id,
            name: playlist.name,
            description: playlist.description ?? '',
            songs: playlist.songs,
            createdAt: playlist.createdAt ?? Date.now(),
            updatedAt: playlist.updatedAt ?? playlist.createdAt ?? Date.now()
          });
        }
      }
    } catch (err) {
      Logger.warn('UserPlaylistStore', `load failed: ${(err as Error).message}`);
      this.playlists = [];
    }
    this.publishRevision();
  }

  private async persist(): Promise<void> {
    if (this.store === null || this.loadedAccountKey.length === 0) {
      return;
    }
    await this.store.put(`${KEY_PREFIX}${this.loadedAccountKey}`, JSON.stringify(this.playlists));
    await this.store.flush();
  }

  private publishRevision(): void {
    const current: number | undefined = AppStorage.get<number>('userPlaylistRevision');
    if (current === undefined) {
      AppStorage.setOrCreate<number>('userPlaylistRevision', 1);
      return;
    }
    AppStorage.set<number>('userPlaylistRevision', current + 1);
  }

  private static copyPlaylist(source: UserPlaylist): UserPlaylist {
    const copy: UserPlaylist = {
      id: source.id,
      name: source.name,
      description: source.description,
      songs: source.songs.slice(),
      createdAt: source.createdAt,
      updatedAt: source.updatedAt
    };
    return copy;
  }

  private static deduplicateSongs(songs: Song[]): Song[] {
    const seen: Set<string> = new Set<string>();
    const result: Song[] = [];
    for (let i: number = 0; i < songs.length; i++) {
      if (!seen.has(songs[i].id)) {
        seen.add(songs[i].id);
        result.push(songs[i]);
      }
    }
    return result;
  }

  private static computeAccountKey(): string {
    const auth = AuthStore.getInstance().getCredentials();
    if (auth === null) {
      return '';
    }
    let server: string = auth.remoteServerUrl;
    try {
      server = SubsonicUrlUtil.normalizeServerUrl(auth.remoteServerUrl);
    } catch (_err) {
      server = auth.remoteServerUrl.trim();
    }
    return `${server}::${auth.username}`;
  }
}
