import { SubsonicApiError } from '../api/SubsonicTypes';
import { AuthStore, SavedAuth } from './AuthStore';
import { Logger } from '../common/Logger';
import { NetworkStatus } from '../common/NetworkStatus';
import { EndpointRouter } from '../network/routing/EndpointRouter';
import { NetworkCoordinator } from '../network/coordinator/NetworkCoordinator';
import { SongMetadataCache } from '../cache/SongMetadataCache';
import { PlaybackService } from '../playback/PlaybackService';
import { PlaybackPipeline } from '../playback/pipeline/PlaybackPipeline';
import { RecentPlayHistoryStore } from '../settings/RecentPlayHistoryStore';
import { UserPlaylistStore } from '../settings/UserPlaylistStore';
import { PlaylistArtworkStore } from '../settings/PlaylistArtworkStore';
import { CoverCache } from '../playback/CoverCache';
import { MusicViewModel } from '../viewmodel/MusicViewModel';
import { FavoriteSyncService } from '../domain/music/FavoriteSyncService';
import { LyricsRepository } from '../domain/lyrics/LyricsRepository';
import { MusicTagWebOpenApiClient } from '../enhanced/MusicTagWebOpenApiClient';
import { ProfileAppearanceStore } from '../settings/ProfileAppearanceStore';

export type AuthPhase = 'booting' | 'anonymous' | 'authenticated';

export class AuthSession {
  private static transitionChain: Promise<void> = Promise.resolve();
  private static phase: AuthPhase = 'booting';

  static refreshNetworkType(): void {
    AppStorage.setOrCreate<string>('networkType', NetworkStatus.getNetworkType());
  }

  static getPhase(): AuthPhase {
    return AuthSession.phase;
  }

  static async bootstrap(): Promise<void> {
    return AuthSession.enqueueTransition(async (): Promise<void> => {
      AuthSession.publishSnapshot('booting');
      await AuthStore.getInstance().ensureReady();
      let creds: SavedAuth | null = AuthStore.getInstance().getCredentials();
      if (creds === null) {
        await AuthSession.exitAuthenticated();
        creds = AuthStore.getInstance().getCredentials();
        if (creds === null) {
          AuthSession.publishSnapshot('anonymous');
          return;
        }
      }
      await AuthSession.enterAuthenticated(creds);
      AuthSession.publishSnapshot('authenticated', creds);
    });
  }

  static async signIn(auth: SavedAuth): Promise<void> {
    return AuthSession.enqueueTransition(async (): Promise<void> => {
      await AuthSession.enterAuthenticated(auth);
      AuthSession.publishSnapshot('authenticated', auth);
    });
  }

  static async signOut(): Promise<void> {
    return AuthSession.enqueueTransition(async (): Promise<void> => {
      await AuthStore.getInstance().clear();
      await AuthSession.exitAuthenticated();
      AuthSession.publishSnapshot('anonymous');
    });
  }

  static async invalidateIfAuthError(err: Error): Promise<boolean> {
    if (err instanceof SubsonicApiError && (err.code === 40 || err.code === 41)) {
      await AuthSession.signOut();
      return true;
    }
    return false;
  }

  private static enqueueTransition(work: () => Promise<void>): Promise<void> {
    const run: Promise<void> = AuthSession.transitionChain.then(work);
    AuthSession.transitionChain = run.catch(() => {
    });
    return run;
  }

  private static publishSnapshot(phase: AuthPhase, auth?: SavedAuth): void {
    AuthSession.phase = phase;
    AppStorage.setOrCreate<string>('authPhase', phase);
    const loggedIn: boolean = phase === 'authenticated';
    AppStorage.setOrCreate<boolean>('isLoggedIn', loggedIn);
    if (loggedIn && auth !== undefined) {
      const activeServer: string = AuthStore.resolveEndpointUrl(auth, auth.activeEndpoint);
      AppStorage.setOrCreate<string>('loggedInServer', activeServer);
      AppStorage.setOrCreate<string>('loggedInUser', auth.username);
      AppStorage.setOrCreate<string>('loggedInEndpoint', auth.activeEndpoint);
      return;
    }
    AppStorage.setOrCreate<string>('loggedInServer', '');
    AppStorage.setOrCreate<string>('loggedInUser', '');
    AppStorage.setOrCreate<string>('loggedInEndpoint', 'remote');
  }

  private static async enterAuthenticated(auth: SavedAuth): Promise<void> {
    EndpointRouter.start();
    NetworkCoordinator.init();
    PlaybackPipeline.initialize();
    const openApiClient: MusicTagWebOpenApiClient = MusicTagWebOpenApiClient.getInstance();
    LyricsRepository.configureEnhancedProvider(openApiClient);
    ProfileAppearanceStore.getInstance().configureProvider(openApiClient);
    void EndpointRouter.bootstrap(auth);
  }

  private static async exitAuthenticated(): Promise<void> {
    EndpointRouter.stop();
    NetworkCoordinator.shutdown();
    SongMetadataCache.clear();
    RecentPlayHistoryStore.getInstance().clearMemory();
    UserPlaylistStore.getInstance().clearMemory();
    PlaylistArtworkStore.getInstance().clearMemory();
    CoverCache.releaseAll();
    MusicViewModel.getInstance().reset();
    FavoriteSyncService.getInstance().clear();
    LyricsRepository.configureEnhancedProvider(null);
    ProfileAppearanceStore.getInstance().configureProvider(null);
    await PlaybackService.release();
  }
}
