import { MusicListKind, Song } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { AuthSession } from '../auth/AuthSession';
import { CoverDisplayResolver } from '../cache/CoverDisplayResolver';
import { SongMetadataCache } from '../cache/SongMetadataCache';
import { MusicTabSettingsStore } from '../settings/MusicTabSettingsStore';
import { RecentPlayHistoryStore } from '../settings/RecentPlayHistoryStore';

export const RANDOM_SONGS_SIZE: number = 100;
export const MUSIC_PAGE_SIZE: number = 60;
const ALBUM_BATCH_SIZE: number = 12;

interface RecentPageResult {
  songs: Song[];
  nextOffset: number;
  hasMore: boolean;
}

@Observed
export class MusicViewModel {
  private static session: MusicViewModel | null = null;

  kind: MusicListKind = 'random';
  songs: Song[] = [];
  searchQuery: string = '';
  isSearchMode: boolean = false;
  isLoading: boolean = false;
  isLoadingMore: boolean = false;
  hasMore: boolean = false;
  errorMessage: string = '';
  authExpired: boolean = false;
  /** recent：song 索引；frequent/newest：album batch offset */
  private listOffset: number = 0;
  private randomSongsCache: Song[] = [];
  private randomFetched: boolean = false;

  /** 跨 MusicPage 重建保留列表态（外屏预览、二级页返回等） */
  static getInstance(): MusicViewModel {
    if (MusicViewModel.session === null) {
      MusicViewModel.session = new MusicViewModel();
    }
    return MusicViewModel.session;
  }

  reset(): void {
    this.songs = [];
    this.searchQuery = '';
    this.isSearchMode = false;
    this.isLoading = false;
    this.isLoadingMore = false;
    this.hasMore = false;
    this.errorMessage = '';
    this.authExpired = false;
    this.listOffset = 0;
    this.randomSongsCache = [];
    this.randomFetched = false;
  }

  async restoreKindFromStore(): Promise<void> {
    await MusicTabSettingsStore.getInstance().ensureReady();
    this.kind = MusicTabSettingsStore.getInstance().getKind();
  }

  async setKind(nextKind: MusicListKind): Promise<void> {
    if (nextKind !== 'recent' && this.kind === nextKind && !this.isSearchMode && this.songs.length > 0) {
      return;
    }
    if (this.kind === 'random' && !this.isSearchMode && this.songs.length > 0) {
      this.randomSongsCache = this.songs.slice();
      this.randomFetched = true;
    }
    this.kind = nextKind;
    await MusicTabSettingsStore.getInstance().setKind(nextKind);
    await this.loadCurrentKind();
  }

  clearSearchMode(): void {
    this.isSearchMode = false;
    this.searchQuery = '';
  }

  async reloadRandom(): Promise<void> {
    if (this.isLoading || this.kind !== 'random') {
      return;
    }
    this.isSearchMode = false;
    this.searchQuery = '';
    this.isLoading = true;
    this.errorMessage = '';
    this.authExpired = false;
    this.hasMore = false;
    this.listOffset = 0;
    this.randomFetched = false;
    this.randomSongsCache = [];
    try {
      const loaded: Song[] = await SubsonicClient.getInstance().getRandomSongs(RANDOM_SONGS_SIZE);
      this.songs = loaded;
      this.randomSongsCache = loaded.slice();
      this.randomFetched = true;
    } catch (err) {
      await this.handleLoadError(err as Error);
      this.songs = [];
      this.randomSongsCache = [];
      this.randomFetched = false;
    } finally {
      this.isLoading = false;
    }
  }

  async loadCurrentKind(): Promise<void> {
    if (this.isSearchMode) {
      return;
    }
    if (this.kind === 'random') {
      if (this.randomFetched && this.randomSongsCache.length > 0) {
        this.songs = this.randomSongsCache.slice();
        this.hasMore = false;
        this.errorMessage = '';
        this.authExpired = false;
        return;
      }
      await this.reloadRandom();
      return;
    }
    if (this.kind === 'recent') {
      await this.loadRecentPlayed(true);
      return;
    }
    await this.loadAlbumDerived(true);
  }

  private async fetchRecentPage(offset: number, limit: number): Promise<RecentPageResult> {
    await RecentPlayHistoryStore.getInstance().ensureReady();
    const ids: string[] = RecentPlayHistoryStore.getInstance().listSongIds(offset, limit);
    const total: number = RecentPlayHistoryStore.getInstance().totalCount();
    if (ids.length === 0) {
      return { songs: [], nextOffset: offset, hasMore: offset < total };
    }
    const songs: Song[] = await SongMetadataCache.getMany(ids);
    const nextOffset: number = offset + ids.length;
    return { songs: songs, nextOffset: nextOffset, hasMore: nextOffset < total };
  }

  private async loadRecentPlayed(reset: boolean): Promise<void> {
    if (this.isLoading) {
      return;
    }
    if (reset) {
      this.listOffset = 0;
      this.songs = [];
      this.hasMore = true;
    }
    this.isSearchMode = false;
    this.searchQuery = '';
    this.isLoading = true;
    this.errorMessage = '';
    this.authExpired = false;
    try {
      const page: RecentPageResult = await this.fetchRecentPage(this.listOffset, MUSIC_PAGE_SIZE);
      if (reset) {
        this.songs = page.songs;
      } else if (page.songs.length > 0) {
        this.songs = this.songs.concat(page.songs);
      }
      this.listOffset = page.nextOffset;
      this.hasMore = page.hasMore;
    } catch (err) {
      await this.handleLoadError(err as Error);
      if (reset) {
        this.songs = [];
      }
      this.hasMore = false;
    } finally {
      this.isLoading = false;
    }
  }

  private async loadAlbumDerived(reset: boolean): Promise<void> {
    if (this.isLoading) {
      return;
    }
    if (reset) {
      this.listOffset = 0;
      this.songs = [];
      this.hasMore = true;
    }
    this.isSearchMode = false;
    this.searchQuery = '';
    this.isLoading = true;
    this.errorMessage = '';
    this.authExpired = false;
    try {
      const batch: Song[] = await SubsonicClient.getInstance().getSongsViaAlbumList(
        this.kind, ALBUM_BATCH_SIZE, this.listOffset);
      if (reset) {
        this.songs = batch;
      } else if (batch.length > 0) {
        this.songs = MusicViewModel.mergeSongs(this.songs, batch);
      }
      this.listOffset += ALBUM_BATCH_SIZE;
      this.hasMore = batch.length >= ALBUM_BATCH_SIZE;
    } catch (err) {
      await this.handleLoadError(err as Error);
      if (reset) {
        this.songs = [];
      }
      this.hasMore = false;
    } finally {
      this.isLoading = false;
    }
  }

  async loadMore(): Promise<void> {
    if (this.kind === 'random' || this.isSearchMode || this.isLoading ||
      this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    try {
      if (this.kind === 'recent') {
        const page: RecentPageResult = await this.fetchRecentPage(this.listOffset, MUSIC_PAGE_SIZE);
        if (page.songs.length > 0) {
          this.songs = this.songs.concat(page.songs);
        }
        this.listOffset = page.nextOffset;
        this.hasMore = page.hasMore;
        return;
      }
      const batch: Song[] = await SubsonicClient.getInstance().getSongsViaAlbumList(
        this.kind, ALBUM_BATCH_SIZE, this.listOffset);
      if (batch.length > 0) {
        this.songs = MusicViewModel.mergeSongs(this.songs, batch);
      }
      this.listOffset += ALBUM_BATCH_SIZE;
      this.hasMore = batch.length >= ALBUM_BATCH_SIZE;
    } catch (err) {
      const expired: boolean = await AuthSession.invalidateIfAuthError(err as Error);
      if (expired) {
        this.authExpired = true;
        this.errorMessage = '登录已失效，请重新登录';
      }
      this.hasMore = false;
    } finally {
      this.isLoadingMore = false;
    }
  }

  async searchSongs(query: string): Promise<void> {
    const normalized: string = query.trim();
    if (normalized.length === 0) {
      this.isSearchMode = false;
      this.searchQuery = '';
      await this.loadCurrentKind();
      return;
    }
    if (this.isLoading) {
      return;
    }
    this.searchQuery = normalized;
    this.isSearchMode = true;
    this.isLoading = true;
    this.errorMessage = '';
    this.authExpired = false;
    this.hasMore = false;
    try {
      const resp = await SubsonicClient.getInstance().search3(normalized, 0, 0, 50);
      this.songs = resp.searchResult3?.song ?? [];
    } catch (err) {
      await this.handleLoadError(err as Error);
      this.songs = [];
    } finally {
      this.isLoading = false;
    }
  }

  private async handleLoadError(err: Error): Promise<void> {
    const expired: boolean = await AuthSession.invalidateIfAuthError(err);
    if (expired) {
      this.authExpired = true;
      this.errorMessage = '登录已失效，请重新登录';
    } else {
      this.errorMessage = err.message;
    }
  }

  private static mergeSongs(existing: Song[], incoming: Song[]): Song[] {
    const seen: Set<string> = new Set<string>();
    const merged: Song[] = [];
    for (let i: number = 0; i < existing.length; i++) {
      seen.add(existing[i].id);
      merged.push(existing[i]);
    }
    for (let i: number = 0; i < incoming.length; i++) {
      if (!seen.has(incoming[i].id)) {
        seen.add(incoming[i].id);
        merged.push(incoming[i]);
      }
    }
    return merged;
  }

  async removeFromRecent(songId: string): Promise<void> {
    const removed: boolean = await RecentPlayHistoryStore.getInstance().removeSong(songId);
    if (!removed) {
      return;
    }
    const nextSongs: Song[] = [];
    for (let i: number = 0; i < this.songs.length; i++) {
      if (this.songs[i].id !== songId) {
        nextSongs.push(this.songs[i]);
      }
    }
    this.songs = nextSongs;
    const total: number = RecentPlayHistoryStore.getInstance().totalCount();
    this.hasMore = this.listOffset < total;
  }

  coverUrl(coverArt: string | undefined): string | undefined {
    if (coverArt === undefined || coverArt.length === 0) {
      return undefined;
    }
    return CoverDisplayResolver.resolve(coverArt, 120);
  }
}
