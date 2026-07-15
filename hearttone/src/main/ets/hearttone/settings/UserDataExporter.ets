import { Song } from '../api/SubsonicTypes';
import { AuthStore, SavedAuth } from '../auth/AuthStore';
import { CoverCacheSettingsStore } from '../cache/CoverCacheSettingsStore';
import { AutoCacheMode, CacheLimitGb } from '../cache/SongCacheTypes';
import { SongCacheSettingsStore } from '../cache/SongCacheSettingsStore';
import { ListeningEvent, RecentPlayHistoryStore } from './RecentPlayHistoryStore';
import { MusicTabSettingsStore } from './MusicTabSettingsStore';
import { PlaylistArtworkStore } from './PlaylistArtworkStore';
import { ProfileAppearanceStore } from './ProfileAppearanceStore';
import { UserPlaylist, UserPlaylistStore } from './UserPlaylistStore';

export interface UserDataExportOptions {
  includePlaylists: boolean;
  includeListeningHistory: boolean;
  includePreferences: boolean;
}

export interface UserDataExportSummary {
  playlistCount: number;
  songCount: number;
  listeningEventCount: number;
}

export interface UserDataExportResult {
  json: string;
  summary: UserDataExportSummary;
}

export interface ExportAccount {
  remoteServerUrl: string;
  username: string;
}

export interface ExportPlaylist {
  id: string;
  name: string;
  description: string;
  songs: Song[];
  createdAt: number;
  updatedAt: number;
  coverArtId: string;
}

export interface ExportAppearancePreferences {
  randomImageApi: string;
  backgroundBlur: number;
  backgroundMask: number;
  remoteAvatarUri: string;
  remoteBackgroundUri: string;
}

export interface ExportCachePreferences {
  songAutoCacheMode: AutoCacheMode;
  songLimitGb: CacheLimitGb;
  coverAutoCacheMode: AutoCacheMode;
  coverLimitGb: CacheLimitGb;
}

export interface ExportPreferences {
  musicListKind: string;
  appearance: ExportAppearancePreferences;
  cache: ExportCachePreferences;
}

export interface HeartToneUserDataCopy {
  format: string;
  version: number;
  exportedAt: string;
  account?: ExportAccount;
  playlists?: ExportPlaylist[];
  listeningHistory?: ListeningEvent[];
  preferences?: ExportPreferences;
}

export class UserDataExporter {
  static async export(options: UserDataExportOptions): Promise<UserDataExportResult> {
    const payload: HeartToneUserDataCopy = {
      format: 'hearttone-user-data',
      version: 1,
      exportedAt: new Date().toISOString()
    };
    const auth: SavedAuth | null = AuthStore.getInstance().getCredentials();
    if (auth !== null) {
      payload.account = { remoteServerUrl: auth.remoteServerUrl, username: auth.username };
    }
    let playlistCount: number = 0;
    let songCount: number = 0;
    let listeningEventCount: number = 0;
    if (options.includePlaylists) {
      const playlistStore: UserPlaylistStore = UserPlaylistStore.getInstance();
      const artworkStore: PlaylistArtworkStore = PlaylistArtworkStore.getInstance();
      await playlistStore.ensureReady();
      await artworkStore.ensureReady();
      const playlists: UserPlaylist[] = playlistStore.list();
      const exportedPlaylists: ExportPlaylist[] = [];
      for (let i: number = 0; i < playlists.length; i++) {
        const playlist: UserPlaylist = playlists[i];
        const item: ExportPlaylist = {
          id: playlist.id,
          name: playlist.name,
          description: playlist.description,
          songs: playlist.songs,
          createdAt: playlist.createdAt,
          updatedAt: playlist.updatedAt,
          coverArtId: artworkStore.artworkFor(playlist.id).coverArtId
        };
        exportedPlaylists.push(item);
        songCount += playlist.songs.length;
      }
      payload.playlists = exportedPlaylists;
      playlistCount = exportedPlaylists.length;
    }
    if (options.includeListeningHistory) {
      const historyStore: RecentPlayHistoryStore = RecentPlayHistoryStore.getInstance();
      await historyStore.ensureReady();
      const events: ListeningEvent[] = historyStore.listListeningEvents(90);
      payload.listeningHistory = events;
      listeningEventCount = events.length;
    }
    if (options.includePreferences) {
      const musicTab: MusicTabSettingsStore = MusicTabSettingsStore.getInstance();
      const songCache: SongCacheSettingsStore = SongCacheSettingsStore.getInstance();
      const coverCache: CoverCacheSettingsStore = CoverCacheSettingsStore.getInstance();
      await musicTab.ensureReady();
      await songCache.ensureReady();
      await coverCache.ensureReady();
      const appearance: ProfileAppearanceStore = ProfileAppearanceStore.getInstance();
      payload.preferences = {
        musicListKind: musicTab.getKind(),
        appearance: {
          randomImageApi: appearance.randomApiUrl(),
          backgroundBlur: appearance.backgroundBlur(),
          backgroundMask: appearance.backgroundMask(),
          remoteAvatarUri: UserDataExporter.remoteOnly(appearance.avatarUri()),
          remoteBackgroundUri: UserDataExporter.remoteOnly(appearance.coverUri())
        },
        cache: {
          songAutoCacheMode: songCache.getAutoCacheMode(),
          songLimitGb: songCache.getLimitGb(),
          coverAutoCacheMode: coverCache.getAutoCacheMode(),
          coverLimitGb: coverCache.getLimitGb()
        }
      };
    }
    return {
      json: JSON.stringify(payload, null, 2),
      summary: {
        playlistCount: playlistCount,
        songCount: songCount,
        listeningEventCount: listeningEventCount
      }
    };
  }

  private static remoteOnly(uri: string): string {
    return uri.startsWith('https://') || uri.startsWith('http://') ? uri : '';
  }
}
