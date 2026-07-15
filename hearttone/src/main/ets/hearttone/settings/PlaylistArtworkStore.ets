import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { AuthStore } from '../auth/AuthStore';
import { CacheFileUri } from '../common/CacheFileUri';
import { CacheFileUtil } from '../common/CacheFileUtil';
import { SubsonicUrlUtil } from '../network/api/SubsonicUrlUtil';
import { ProfileAppearanceStore } from './ProfileAppearanceStore';

const STORE_NAME: string = 'hearttone_playlist_artwork';
const KEY_PREFIX: string = 'artwork_';

interface PersistedPlaylistArtwork {
  playlistId: string;
  localPath: string;
  coverArtId: string;
}

export interface PlaylistArtwork {
  imageUri: string;
  coverArtId: string;
}

export interface PlaylistArtworkRestoreItem {
  playlistId: string;
  coverArtId: string;
}

export class PlaylistArtworkStore {
  private static instance: PlaylistArtworkStore | null = null;
  private store: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private loadedAccountKey: string = '';
  private entries: PersistedPlaylistArtwork[] = [];

  private constructor() {
  }

  static getInstance(): PlaylistArtworkStore {
    if (PlaylistArtworkStore.instance === null) {
      PlaylistArtworkStore.instance = new PlaylistArtworkStore();
    }
    return PlaylistArtworkStore.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store === null) {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
    }
    await this.ensureReady();
  }

  async ensureReady(): Promise<void> {
    const accountKey: string = PlaylistArtworkStore.computeAccountKey();
    if (accountKey === this.loadedAccountKey) {
      return;
    }
    this.loadedAccountKey = accountKey;
    this.entries = [];
    if (this.store === null || accountKey.length === 0) {
      this.publish();
      return;
    }
    try {
      const raw: string = (await this.store.get(`${KEY_PREFIX}${accountKey}`, '[]')) as string;
      const parsed: PersistedPlaylistArtwork[] = JSON.parse(raw) as PersistedPlaylistArtwork[];
      if (Array.isArray(parsed)) {
        this.entries = parsed.filter((entry: PersistedPlaylistArtwork) =>
          entry.playlistId !== undefined && entry.playlistId.length > 0);
      }
    } catch (_err) {
      this.entries = [];
    }
    this.publish();
  }

  artworkFor(playlistId: string): PlaylistArtwork {
    const entry: PersistedPlaylistArtwork | undefined = this.entries.find(
      (item: PersistedPlaylistArtwork) => item.playlistId === playlistId);
    if (entry === undefined) {
      return { imageUri: '', coverArtId: '' };
    }
    return {
      imageUri: entry.localPath.length > 0 ? PlaylistArtworkStore.resolveUri(entry.localPath) : '',
      coverArtId: entry.coverArtId
    };
  }

  async setManualImage(playlistId: string, sourceUri: string): Promise<void> {
    await this.ensureReady();
    if (this.context === null) {
      throw new Error('歌单封面存储尚未初始化');
    }
    const targetPath: string = `${this.context.filesDir}/playlist_cover_${Date.now()}.jpg`;
    await fileIo.copyFile(sourceUri, targetPath);
    await this.replace(playlistId, targetPath, '');
  }

  async setRandomImage(playlistId: string): Promise<void> {
    await this.ensureReady();
    if (this.context === null) {
      throw new Error('歌单封面存储尚未初始化');
    }
    const request: http.HttpRequest = http.createHttp();
    const targetPath: string = `${this.context.filesDir}/playlist_cover_${Date.now()}.jpg`;
    try {
      const response: http.HttpResponse = await request.request(
        ProfileAppearanceStore.getInstance().randomAvatarUrl(),
        {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: 12000,
          readTimeout: 20000
        }
      );
      if (response.responseCode < 200 || response.responseCode >= 400) {
        throw new Error(`图片 API 请求失败（HTTP ${response.responseCode}）`);
      }
      PlaylistArtworkStore.writeBuffer(targetPath, response.result as ArrayBuffer);
      await this.replace(playlistId, targetPath, '');
    } finally {
      request.destroy();
    }
  }

  async setAlbumCover(playlistId: string, coverArtId: string): Promise<void> {
    await this.ensureReady();
    if (coverArtId.length === 0) {
      throw new Error('该歌曲没有专辑封面');
    }
    await this.replace(playlistId, '', coverArtId);
  }

  async clear(playlistId: string): Promise<void> {
    await this.ensureReady();
    const old: PersistedPlaylistArtwork | undefined = this.entries.find(
      (entry: PersistedPlaylistArtwork) => entry.playlistId === playlistId);
    if (old !== undefined) {
      PlaylistArtworkStore.removeLocal(old.localPath);
    }
    this.entries = this.entries.filter((entry: PersistedPlaylistArtwork) => entry.playlistId !== playlistId);
    await this.persist();
    this.publish();
  }

  async clearMany(playlistIds: string[]): Promise<void> {
    await this.ensureReady();
    const selectedIds: Set<string> = new Set<string>(playlistIds);
    for (let i: number = 0; i < this.entries.length; i++) {
      if (selectedIds.has(this.entries[i].playlistId)) {
        PlaylistArtworkStore.removeLocal(this.entries[i].localPath);
      }
    }
    this.entries = this.entries.filter(
      (entry: PersistedPlaylistArtwork) => !selectedIds.has(entry.playlistId));
    await this.persist();
    this.publish();
  }

  async restoreAlbumCovers(items: PlaylistArtworkRestoreItem[], replaceExisting: boolean): Promise<void> {
    await this.ensureReady();
    if (replaceExisting) {
      for (let i: number = 0; i < this.entries.length; i++) {
        PlaylistArtworkStore.removeLocal(this.entries[i].localPath);
      }
      this.entries = [];
    }
    for (let i: number = 0; i < items.length; i++) {
      const item: PlaylistArtworkRestoreItem = items[i];
      if (item.playlistId.length === 0 || item.coverArtId.length === 0) {
        continue;
      }
      const old: PersistedPlaylistArtwork | undefined = this.entries.find(
        (entry: PersistedPlaylistArtwork) => entry.playlistId === item.playlistId);
      if (old !== undefined) {
        PlaylistArtworkStore.removeLocal(old.localPath);
      }
      this.entries = this.entries.filter(
        (entry: PersistedPlaylistArtwork) => entry.playlistId !== item.playlistId);
      this.entries.push({ playlistId: item.playlistId, localPath: '', coverArtId: item.coverArtId });
    }
    await this.persist();
    this.publish();
  }

  async clearAllData(): Promise<void> {
    await this.ensureReady();
    for (let i: number = 0; i < this.entries.length; i++) {
      PlaylistArtworkStore.removeLocal(this.entries[i].localPath);
    }
    this.entries = [];
    if (this.store !== null && this.loadedAccountKey.length > 0) {
      await this.store.delete(`${KEY_PREFIX}${this.loadedAccountKey}`);
      await this.store.flush();
    }
    this.publish();
  }

  clearMemory(): void {
    this.entries = [];
    this.loadedAccountKey = '';
    this.publish();
  }

  private async replace(playlistId: string, localPath: string, coverArtId: string): Promise<void> {
    const old: PersistedPlaylistArtwork | undefined = this.entries.find(
      (entry: PersistedPlaylistArtwork) => entry.playlistId === playlistId);
    if (old !== undefined && old.localPath !== localPath) {
      PlaylistArtworkStore.removeLocal(old.localPath);
    }
    this.entries = this.entries.filter((entry: PersistedPlaylistArtwork) => entry.playlistId !== playlistId);
    this.entries.push({ playlistId: playlistId, localPath: localPath, coverArtId: coverArtId });
    await this.persist();
    this.publish();
  }

  private async persist(): Promise<void> {
    if (this.store === null || this.loadedAccountKey.length === 0) {
      return;
    }
    await this.store.put(`${KEY_PREFIX}${this.loadedAccountKey}`, JSON.stringify(this.entries));
    await this.store.flush();
  }

  private publish(): void {
    const revision: number = AppStorage.get<number>('playlistArtworkRevision') ?? 0;
    AppStorage.setOrCreate<number>('playlistArtworkRevision', revision + 1);
  }

  private static resolveUri(path: string): string {
    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('file://')) {
      return path;
    }
    return CacheFileUri.fromAbsolutePath(path);
  }

  private static writeBuffer(path: string, data: ArrayBuffer): void {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    try {
      fileIo.writeSync(file.fd, data, { offset: 0, length: data.byteLength });
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static removeLocal(path: string): void {
    if (path.length > 0 && !path.startsWith('http://') && !path.startsWith('https://') &&
      !path.startsWith('file://')) {
      CacheFileUtil.removeIfExists(path);
    }
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
