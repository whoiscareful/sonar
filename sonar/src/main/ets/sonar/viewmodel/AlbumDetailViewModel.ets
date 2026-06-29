import { AlbumDetailContainer, Song } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { AuthSession } from '../auth/AuthSession';
import { CoverDisplayResolver } from '../cache/CoverDisplayResolver';

@Observed
export class AlbumDetailViewModel {
  album: AlbumDetailContainer | null = null;
  songs: Song[] = [];
  isLoading: boolean = false;
  errorMessage: string = '';
  authExpired: boolean = false;

  async load(albumId: string): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.errorMessage = '';
    this.authExpired = false;
    try {
      const resp = await SubsonicClient.getInstance().getAlbum(albumId);
      this.album = resp.album;
      this.songs = resp.album.song ?? [];
    } catch (err) {
      const expired: boolean = await AuthSession.invalidateIfAuthError(err as Error);
      if (expired) {
        this.authExpired = true;
        this.errorMessage = '登录已失效，请重新登录';
      } else {
        this.errorMessage = (err as Error).message;
      }
      this.album = null;
      this.songs = [];
    } finally {
      this.isLoading = false;
    }
  }

  coverUrl(coverArt: string | undefined): string | undefined {
    if (coverArt === undefined || coverArt.length === 0) {
      return undefined;
    }
    return CoverDisplayResolver.resolve(coverArt, 480);
  }
}
