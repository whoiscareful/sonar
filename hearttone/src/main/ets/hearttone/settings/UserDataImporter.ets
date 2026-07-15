import { MusicListKind, Song } from '../api/SubsonicTypes';
import { AuthStore, SavedAuth } from '../auth/AuthStore';
import { CoverCacheSettingsStore } from '../cache/CoverCacheSettingsStore';
import { AutoCacheMode, CacheLimitGb } from '../cache/SongCacheTypes';
import { SongCacheSettingsStore } from '../cache/SongCacheSettingsStore';
import { SubsonicUrlUtil } from '../network/api/SubsonicUrlUtil';
import { ListeningEvent, RecentPlayHistoryStore } from './RecentPlayHistoryStore';
import { MusicTabSettingsStore } from './MusicTabSettingsStore';
import { PlaylistArtworkRestoreItem, PlaylistArtworkStore } from './PlaylistArtworkStore';
import { ProfileAppearanceStore } from './ProfileAppearanceStore';
import {
  ExportAccount,
  ExportAppearancePreferences,
  ExportCachePreferences,
  ExportPlaylist,
  ExportPreferences,
  HeartToneUserDataCopy
} from './UserDataExporter';
import { UserPlaylist, UserPlaylistStore } from './UserPlaylistStore';

export interface UserDataImportPreview {
  exportedAt: string;
  accountText: string;
  accountMismatch: boolean;
  hasPlaylists: boolean;
  hasListeningHistory: boolean;
  hasPreferences: boolean;
  playlistCount: number;
  songCount: number;
  listeningEventCount: number;
  currentPlaylistCount: number;
  matchingPlaylistCount: number;
}

export interface UserDataRestoreOptions {
  includePlaylists: boolean;
  includeListeningHistory: boolean;
  includePreferences: boolean;
  replaceExisting: boolean;
}

export interface UserDataRestoreResult {
  playlistCount: number;
  listeningEventCount: number;
  preferencesRestored: boolean;
}

export class UserDataImportPackage {
  readonly payload: HeartToneUserDataCopy;
  readonly preview: UserDataImportPreview;

  constructor(payload: HeartToneUserDataCopy, preview: UserDataImportPreview) {
    this.payload = payload;
    this.preview = preview;
  }
}

export class UserDataImporter {
  static async inspect(json: string): Promise<UserDataImportPackage> {
    let parsed: HeartToneUserDataCopy;
    try {
      parsed = JSON.parse(json) as HeartToneUserDataCopy;
    } catch (_err) {
      throw new Error('文件不是有效的 JSON 数据');
    }
    const payload: HeartToneUserDataCopy = UserDataImporter.normalizePayload(parsed);
    const playlistStore: UserPlaylistStore = UserPlaylistStore.getInstance();
    await playlistStore.ensureReady();
    const currentPlaylists: UserPlaylist[] = playlistStore.list();
    const currentIds: Set<string> = new Set<string>();
    for (let i: number = 0; i < currentPlaylists.length; i++) {
      currentIds.add(currentPlaylists[i].id);
    }
    let songCount: number = 0;
    let matchingPlaylistCount: number = 0;
    const playlists: ExportPlaylist[] = payload.playlists ?? [];
    for (let i: number = 0; i < playlists.length; i++) {
      songCount += playlists[i].songs.length;
      if (currentIds.has(playlists[i].id)) {
        matchingPlaylistCount += 1;
      }
    }
    const auth: SavedAuth | null = AuthStore.getInstance().getCredentials();
    const preview: UserDataImportPreview = {
      exportedAt: payload.exportedAt,
      accountText: UserDataImporter.accountText(payload.account),
      accountMismatch: UserDataImporter.accountMismatch(payload.account, auth),
      hasPlaylists: payload.playlists !== undefined,
      hasListeningHistory: payload.listeningHistory !== undefined,
      hasPreferences: payload.preferences !== undefined,
      playlistCount: playlists.length,
      songCount: songCount,
      listeningEventCount: (payload.listeningHistory ?? []).length,
      currentPlaylistCount: currentPlaylists.length,
      matchingPlaylistCount: matchingPlaylistCount
    };
    return new UserDataImportPackage(payload, preview);
  }

  static async restore(
    importPackage: UserDataImportPackage,
    options: UserDataRestoreOptions
  ): Promise<UserDataRestoreResult> {
    if (AuthStore.getInstance().getCredentials() === null) {
      throw new Error('请先登录服务器，再恢复个人数据');
    }
    const payload: HeartToneUserDataCopy = importPackage.payload;
    let playlistCount: number = 0;
    let listeningEventCount: number = 0;
    let preferencesRestored: boolean = false;
    if (options.includePlaylists && payload.playlists !== undefined) {
      const playlists: UserPlaylist[] = [];
      const artworks: PlaylistArtworkRestoreItem[] = [];
      for (let i: number = 0; i < payload.playlists.length; i++) {
        const source: ExportPlaylist = payload.playlists[i];
        playlists.push({
          id: source.id,
          name: source.name,
          description: source.description,
          songs: source.songs.slice(),
          createdAt: source.createdAt,
          updatedAt: source.updatedAt
        });
        artworks.push({ playlistId: source.id, coverArtId: source.coverArtId });
      }
      await UserPlaylistStore.getInstance().restore(playlists, options.replaceExisting);
      await PlaylistArtworkStore.getInstance().restoreAlbumCovers(artworks, options.replaceExisting);
      playlistCount = playlists.length;
    }
    if (options.includeListeningHistory && payload.listeningHistory !== undefined) {
      await RecentPlayHistoryStore.getInstance().restoreListeningEvents(
        payload.listeningHistory, options.replaceExisting);
      listeningEventCount = payload.listeningHistory.length;
    }
    if (options.includePreferences && payload.preferences !== undefined) {
      await UserDataImporter.restorePreferences(payload.preferences);
      preferencesRestored = true;
    }
    return {
      playlistCount: playlistCount,
      listeningEventCount: listeningEventCount,
      preferencesRestored: preferencesRestored
    };
  }

  private static normalizePayload(source: HeartToneUserDataCopy): HeartToneUserDataCopy {
    if (source === null || source.format !== 'hearttone-user-data') {
      throw new Error('这不是 HeartTone 个人数据副本');
    }
    if (source.version !== 1) {
      throw new Error(`暂不支持此数据版本：${source.version}`);
    }
    if (typeof source.exportedAt !== 'string' || source.exportedAt.length === 0) {
      throw new Error('副本缺少导出时间');
    }
    const payload: HeartToneUserDataCopy = {
      format: source.format,
      version: source.version,
      exportedAt: source.exportedAt
    };
    if (source.account !== undefined) {
      payload.account = UserDataImporter.normalizeAccount(source.account);
    }
    if (source.playlists !== undefined) {
      if (!Array.isArray(source.playlists)) {
        throw new Error('歌单数据格式不正确');
      }
      const playlists: ExportPlaylist[] = [];
      const playlistIds: Set<string> = new Set<string>();
      for (let i: number = 0; i < source.playlists.length; i++) {
        const playlist: ExportPlaylist = UserDataImporter.normalizePlaylist(source.playlists[i]);
        if (!playlistIds.has(playlist.id)) {
          playlistIds.add(playlist.id);
          playlists.push(playlist);
        }
      }
      payload.playlists = playlists;
    }
    if (source.listeningHistory !== undefined) {
      if (!Array.isArray(source.listeningHistory)) {
        throw new Error('听歌记录格式不正确');
      }
      const events: ListeningEvent[] = [];
      for (let i: number = 0; i < source.listeningHistory.length; i++) {
        const event: ListeningEvent | null = UserDataImporter.normalizeListeningEvent(
          source.listeningHistory[i]);
        if (event !== null) {
          events.push(event);
        }
      }
      payload.listeningHistory = events;
    }
    if (source.preferences !== undefined) {
      payload.preferences = UserDataImporter.normalizePreferences(source.preferences);
    }
    if (payload.playlists === undefined && payload.listeningHistory === undefined &&
      payload.preferences === undefined) {
      throw new Error('副本中没有可恢复的个人数据');
    }
    return payload;
  }

  private static normalizeAccount(source: ExportAccount): ExportAccount {
    if (typeof source.remoteServerUrl !== 'string' || typeof source.username !== 'string') {
      throw new Error('账号信息格式不正确');
    }
    return {
      remoteServerUrl: source.remoteServerUrl.trim(),
      username: source.username.trim()
    };
  }

  private static normalizePlaylist(source: ExportPlaylist): ExportPlaylist {
    if (source === null || typeof source.id !== 'string' || source.id.length === 0 ||
      typeof source.name !== 'string' || !Array.isArray(source.songs)) {
      throw new Error('存在无法识别的歌单数据');
    }
    const songs: Song[] = [];
    for (let i: number = 0; i < source.songs.length; i++) {
      const song: Song | null = UserDataImporter.normalizeSong(source.songs[i]);
      if (song !== null) {
        songs.push(song);
      }
    }
    const now: number = Date.now();
    return {
      id: source.id,
      name: source.name.trim().length > 0 ? source.name.trim() : '未命名歌单',
      description: typeof source.description === 'string' ? source.description.trim() : '',
      songs: songs,
      createdAt: typeof source.createdAt === 'number' && source.createdAt > 0 ? source.createdAt : now,
      updatedAt: typeof source.updatedAt === 'number' && source.updatedAt > 0 ? source.updatedAt : now,
      coverArtId: typeof source.coverArtId === 'string' ? source.coverArtId : ''
    };
  }

  private static normalizeSong(source: Song): Song | null {
    if (source === null || typeof source.id !== 'string' || source.id.length === 0 ||
      typeof source.parent !== 'string' || typeof source.isDir !== 'boolean' ||
      typeof source.title !== 'string' || typeof source.album !== 'string' ||
      typeof source.artist !== 'string' || typeof source.size !== 'number' ||
      typeof source.duration !== 'number') {
      return null;
    }
    return source;
  }

  private static normalizeListeningEvent(source: ListeningEvent): ListeningEvent | null {
    if (source === null || typeof source.songId !== 'string' || source.songId.length === 0 ||
      typeof source.title !== 'string' || typeof source.artist !== 'string' ||
      typeof source.durationSec !== 'number' || typeof source.playedAt !== 'number' || source.playedAt <= 0) {
      return null;
    }
    return {
      songId: source.songId,
      title: source.title,
      artist: source.artist,
      durationSec: source.durationSec > 0 ? source.durationSec : 0,
      playedAt: source.playedAt
    };
  }

  private static normalizePreferences(source: ExportPreferences): ExportPreferences {
    if (source === null || source.appearance === undefined || source.cache === undefined) {
      throw new Error('应用偏好格式不正确');
    }
    const kind: string = source.musicListKind;
    if (!UserDataImporter.isMusicListKind(kind)) {
      throw new Error('音乐列表模式无法识别');
    }
    const appearance: ExportAppearancePreferences = source.appearance;
    if (typeof appearance.randomImageApi !== 'string' || typeof appearance.backgroundBlur !== 'number' ||
      typeof appearance.backgroundMask !== 'number' || typeof appearance.remoteAvatarUri !== 'string' ||
      typeof appearance.remoteBackgroundUri !== 'string') {
      throw new Error('外观偏好格式不正确');
    }
    const cache: ExportCachePreferences = source.cache;
    if (!UserDataImporter.isAutoCacheMode(cache.songAutoCacheMode) ||
      !UserDataImporter.isAutoCacheMode(cache.coverAutoCacheMode) ||
      !UserDataImporter.isCacheLimit(cache.songLimitGb) ||
      !UserDataImporter.isCacheLimit(cache.coverLimitGb)) {
      throw new Error('缓存偏好格式不正确');
    }
    return {
      musicListKind: kind,
      appearance: {
        randomImageApi: appearance.randomImageApi,
        backgroundBlur: appearance.backgroundBlur,
        backgroundMask: appearance.backgroundMask,
        remoteAvatarUri: appearance.remoteAvatarUri,
        remoteBackgroundUri: appearance.remoteBackgroundUri
      },
      cache: {
        songAutoCacheMode: cache.songAutoCacheMode,
        songLimitGb: cache.songLimitGb,
        coverAutoCacheMode: cache.coverAutoCacheMode,
        coverLimitGb: cache.coverLimitGb
      }
    };
  }

  private static async restorePreferences(source: ExportPreferences): Promise<void> {
    await MusicTabSettingsStore.getInstance().setKind(source.musicListKind as MusicListKind);
    const appearance: ProfileAppearanceStore = ProfileAppearanceStore.getInstance();
    await appearance.setRandomApiUrl(source.appearance.randomImageApi);
    await appearance.setBackgroundEffects(
      source.appearance.backgroundBlur, source.appearance.backgroundMask);
    if (UserDataImporter.isRemoteUri(source.appearance.remoteAvatarUri)) {
      await appearance.updateAvatarUri(source.appearance.remoteAvatarUri);
    }
    if (UserDataImporter.isRemoteUri(source.appearance.remoteBackgroundUri)) {
      await appearance.updateCoverUri(source.appearance.remoteBackgroundUri);
    }
    const songCache: SongCacheSettingsStore = SongCacheSettingsStore.getInstance();
    const coverCache: CoverCacheSettingsStore = CoverCacheSettingsStore.getInstance();
    await songCache.setAutoCacheMode(source.cache.songAutoCacheMode);
    await songCache.setLimitGb(source.cache.songLimitGb);
    await coverCache.setAutoCacheMode(source.cache.coverAutoCacheMode);
    await coverCache.setLimitGb(source.cache.coverLimitGb);
  }

  private static accountText(account?: ExportAccount): string {
    if (account === undefined) {
      return '副本未记录账号';
    }
    return `${account.username} · ${account.remoteServerUrl}`;
  }

  private static accountMismatch(account: ExportAccount | undefined, auth: SavedAuth | null): boolean {
    if (account === undefined || auth === null) {
      return false;
    }
    return account.username !== auth.username ||
      UserDataImporter.normalizeServer(account.remoteServerUrl) !==
      UserDataImporter.normalizeServer(auth.remoteServerUrl);
  }

  private static normalizeServer(server: string): string {
    try {
      return SubsonicUrlUtil.normalizeServerUrl(server).toLowerCase();
    } catch (_err) {
      return server.trim().replace(/\/+$/, '').toLowerCase();
    }
  }

  private static isMusicListKind(value: string): boolean {
    return value === 'favorite' || value === 'random' || value === 'frequent' ||
      value === 'recent' || value === 'newest';
  }

  private static isAutoCacheMode(value: AutoCacheMode): boolean {
    return value === 'off' || value === 'always' || value === 'wifi_only';
  }

  private static isCacheLimit(value: CacheLimitGb): boolean {
    return value === 1 || value === 2 || value === 5 || value === 10;
  }

  private static isRemoteUri(uri: string): boolean {
    return uri.startsWith('https://') || uri.startsWith('http://');
  }
}
