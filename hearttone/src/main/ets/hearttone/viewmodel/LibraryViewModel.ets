import { Album } from '../api/SubsonicTypes';
import { AuthSession } from '../auth/AuthSession';
import { AuthStore, SavedAuth } from '../auth/AuthStore';
import { CoverDisplayResolver } from '../cache/CoverDisplayResolver';
import { MusicCatalogRepository } from '../domain/music/MusicCatalogRepository';
import { MusicTagWebStats } from '../enhanced/MusicTagWebOpenApi';
import { MusicTagWebOpenApiClient } from '../enhanced/MusicTagWebOpenApiClient';
import { OpenApiCredentialStore } from '../enhanced/OpenApiCredentialStore';

export type LibraryTab = 'newest' | 'frequent' | 'random';

const PAGE_SIZE: number = 60;

@Observed
export class LibraryViewModel {
  tab: LibraryTab = 'newest';
  albums: Album[] = [];
  featuredAlbums: Album[] = [];
  searchQuery: string = '';
  isSearchMode: boolean = false;
  isLoading: boolean = false;
  isLoadingMore: boolean = false;
  hasMore: boolean = true;
  errorMessage: string = '';
  authExpired: boolean = false;
  openApiStats: MusicTagWebStats | null = null;
  openApiStatsLoading: boolean = false;
  openApiStatsError: string = '';
  private readonly catalog: MusicCatalogRepository = MusicCatalogRepository.getInstance();

  reset(): void {
    this.albums = [];
    this.featuredAlbums = [];
    this.searchQuery = '';
    this.isSearchMode = false;
    this.isLoading = false;
    this.isLoadingMore = false;
    this.hasMore = true;
    this.errorMessage = '';
    this.authExpired = false;
    this.openApiStats = null;
    this.openApiStatsLoading = false;
    this.openApiStatsError = '';
  }

  async loadNewest(): Promise<void> {
    await this.loadAlbumFeed('newest');
  }

  async loadFrequent(): Promise<void> {
    await this.loadAlbumFeed('frequent');
  }

  async loadRandom(): Promise<void> {
    await this.loadAlbumFeed('random');
  }

  async loadHome(): Promise<void> {
    await Promise.all([this.loadAlbumFeed('newest'), this.loadFeaturedAlbums()]);
  }

  async loadOpenApiStats(): Promise<void> {
    if (this.openApiStatsLoading) {
      return;
    }
    const token: string = await OpenApiCredentialStore.getToken();
    if (token.length === 0) {
      this.openApiStats = null;
      this.openApiStatsError = '';
      return;
    }
    this.openApiStatsLoading = true;
    this.openApiStatsError = '';
    try {
      const auth: SavedAuth | null = AuthStore.getInstance().getCredentials();
      this.openApiStats = await MusicTagWebOpenApiClient.getInstance().stats(auth?.username,
        'album_count,track_count,artist_count,song_size,song_duration,now_playing');
    } catch (err) {
      this.openApiStats = null;
      this.openApiStatsError = (err as Error).message;
    } finally {
      this.openApiStatsLoading = false;
    }
  }

  private async loadFeaturedAlbums(): Promise<void> {
    try {
      const featuredResp = await this.catalog.albumFeed('random', 8, 0);
      this.featuredAlbums = featuredResp.albumList2.album ?? [];
    } catch (_err) {
      this.featuredAlbums = [];
    }
  }

  private async loadAlbumFeed(tab: LibraryTab): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.tab = tab;
    this.isSearchMode = false;
    this.searchQuery = '';
    this.isLoading = true;
    this.errorMessage = '';
    this.authExpired = false;
    this.hasMore = true;
    try {
      const resp = await this.catalog.albumFeed(tab, PAGE_SIZE, 0);
      const list: Album[] = resp.albumList2.album ?? [];
      this.albums = list;
      this.hasMore = tab !== 'random' && list.length >= PAGE_SIZE;
    } catch (err) {
      const expired: boolean = await AuthSession.invalidateIfAuthError(err as Error);
      if (expired) {
        this.authExpired = true;
        this.errorMessage = '登录已失效，请重新登录';
      } else {
        this.errorMessage = (err as Error).message;
      }
      this.albums = [];
      this.hasMore = false;
    } finally {
      this.isLoading = false;
    }
  }

  async loadMore(): Promise<void> {
    if (this.isSearchMode || this.isLoading || this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    try {
      const resp = await this.catalog.albumFeed(this.tab, PAGE_SIZE, this.albums.length);
      const list: Album[] = resp.albumList2.album ?? [];
      if (list.length > 0) {
        this.albums = this.albums.concat(list);
      }
      this.hasMore = list.length >= PAGE_SIZE;
    } catch (err) {
      const expired: boolean = await AuthSession.invalidateIfAuthError(err as Error);
      if (expired) {
        this.authExpired = true;
        this.errorMessage = '登录已失效，请重新登录';
        this.hasMore = false;
      }
    } finally {
      this.isLoadingMore = false;
    }
  }

  async searchAlbums(query: string): Promise<void> {
    const normalized: string = query.trim();
    if (normalized.length === 0) {
      await this.loadHome();
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
      const resp = await this.catalog.search(normalized, 0, PAGE_SIZE, 0);
      this.albums = resp.searchResult3?.album ?? [];
    } catch (err) {
      const expired: boolean = await AuthSession.invalidateIfAuthError(err as Error);
      if (expired) {
        this.authExpired = true;
        this.errorMessage = '登录已失效，请重新登录';
      } else {
        this.errorMessage = (err as Error).message;
      }
      this.albums = [];
    } finally {
      this.isLoading = false;
    }
  }

  coverUrl(coverArt: string | undefined): string | undefined {
    if (coverArt === undefined || coverArt.length === 0) {
      return undefined;
    }
    return CoverDisplayResolver.resolve(coverArt, 300);
  }
}
