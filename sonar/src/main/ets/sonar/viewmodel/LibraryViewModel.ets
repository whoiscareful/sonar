import { Album } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { AuthSession } from '../auth/AuthSession';
import { CoverDisplayResolver } from '../cache/CoverDisplayResolver';

export type LibraryTab = 'newest' | 'artists' | 'random';

const PAGE_SIZE: number = 60;

@Observed
export class LibraryViewModel {
  tab: LibraryTab = 'newest';
  albums: Album[] = [];
  searchQuery: string = '';
  isSearchMode: boolean = false;
  isLoading: boolean = false;
  isLoadingMore: boolean = false;
  hasMore: boolean = true;
  errorMessage: string = '';
  authExpired: boolean = false;

  reset(): void {
    this.albums = [];
    this.searchQuery = '';
    this.isSearchMode = false;
    this.isLoading = false;
    this.isLoadingMore = false;
    this.hasMore = true;
    this.errorMessage = '';
    this.authExpired = false;
  }

  async loadNewest(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.isSearchMode = false;
    this.searchQuery = '';
    this.isLoading = true;
    this.errorMessage = '';
    this.authExpired = false;
    this.hasMore = true;
    try {
      const resp = await SubsonicClient.getInstance().getAlbumList2('newest', PAGE_SIZE, 0);
      const list: Album[] = resp.albumList2.album ?? [];
      this.albums = list;
      this.hasMore = list.length >= PAGE_SIZE;
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
      const resp = await SubsonicClient.getInstance().getAlbumList2('newest', PAGE_SIZE, this.albums.length);
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

  async loadRandom(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.isSearchMode = false;
    this.searchQuery = '';
    this.isLoading = true;
    this.errorMessage = '';
    this.authExpired = false;
    this.hasMore = false;
    try {
      const resp = await SubsonicClient.getInstance().getAlbumList2('random', PAGE_SIZE, 0);
      this.albums = resp.albumList2.album ?? [];
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

  async searchAlbums(query: string): Promise<void> {
    const normalized: string = query.trim();
    if (normalized.length === 0) {
      await this.loadNewest();
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
      const resp = await SubsonicClient.getInstance().search3(normalized, 0, PAGE_SIZE, 0);
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
