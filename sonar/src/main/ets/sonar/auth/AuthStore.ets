import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Logger } from '../common/Logger';

const STORE_NAME: string = 'sonar_auth';
const KEY_SERVER_URL: string = 'server_url';
const KEY_REMOTE_SERVER_URL: string = 'remote_server_url';
const KEY_LOCAL_SERVER_URL: string = 'local_server_url';
const KEY_ACTIVE_ENDPOINT: string = 'active_endpoint';
const KEY_USERNAME: string = 'username';
const KEY_SALT: string = 'salt';
const KEY_TOKEN: string = 'token';
const KEY_LAST_REMOTE_SERVER_URL: string = 'last_remote_server_url';
const KEY_LAST_LOCAL_SERVER_URL: string = 'last_local_server_url';
const KEY_LAST_USERNAME: string = 'last_username';
const KEY_LAST_PASSWORD: string = 'last_password';

export type EndpointType = 'remote' | 'local';

export interface SavedAuth {
  remoteServerUrl: string;
  localServerUrl?: string;
  activeEndpoint: EndpointType;
  username: string;
  salt: string;
  token: string;
  authMode?: 'subsonicToken';
}

export interface RememberedLoginInfo {
  remoteServerUrl: string;
  localServerUrl: string;
  username: string;
  password: string;
}

export class AuthStore {
  private static instance: AuthStore | null = null;
  private store: preferences.Preferences | null = null;
  private cachedAuth: SavedAuth | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {
  }

  static resolveEndpointUrl(auth: SavedAuth, endpoint: EndpointType): string {
    if (endpoint === 'local' && auth.localServerUrl !== undefined && auth.localServerUrl.length > 0) {
      return auth.localServerUrl;
    }
    return auth.remoteServerUrl;
  }

  static getInstance(): AuthStore {
    if (AuthStore.instance === null) {
      AuthStore.instance = new AuthStore();
    }
    return AuthStore.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store !== null) {
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
      await this.reload();
    } catch (err) {
      Logger.error('AuthStore', `init failed: ${(err as Error).message}`);
    }
  }

  async ensureReady(): Promise<void> {
    if (this.store !== null) {
      return;
    }
    if (this.context === null) {
      Logger.warn('AuthStore', 'ensureReady skipped: missing UIAbilityContext');
      return;
    }
    await this.init(this.context);
  }

  private async reload(): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      const remoteServerUrlNew: string = (await this.store.get(KEY_REMOTE_SERVER_URL, '')) as string;
      const legacyServerUrl: string = (await this.store.get(KEY_SERVER_URL, '')) as string;
      const remoteServerUrl: string = remoteServerUrlNew.length > 0 ? remoteServerUrlNew : legacyServerUrl;
      const localServerUrlRaw: string = (await this.store.get(KEY_LOCAL_SERVER_URL, '')) as string;
      const activeEndpointRaw: string = (await this.store.get(KEY_ACTIVE_ENDPOINT, 'remote')) as string;
      const activeEndpoint: EndpointType = activeEndpointRaw === 'local' ? 'local' : 'remote';
      const username: string = (await this.store.get(KEY_USERNAME, '')) as string;
      const salt: string = (await this.store.get(KEY_SALT, '')) as string;
      const token: string = (await this.store.get(KEY_TOKEN, '')) as string;
      if (remoteServerUrl && username && salt && token) {
        const localServerUrl: string | undefined =
          localServerUrlRaw.length > 0 ? localServerUrlRaw : undefined;
        this.cachedAuth = {
          remoteServerUrl,
          localServerUrl,
          activeEndpoint,
          username,
          salt,
          token,
          authMode: 'subsonicToken'
        };
        if (this.cachedAuth.activeEndpoint === 'local' &&
          (this.cachedAuth.localServerUrl === undefined || this.cachedAuth.localServerUrl.length === 0)) {
          this.cachedAuth.activeEndpoint = 'remote';
        }
      } else {
        this.cachedAuth = null;
      }
    } catch (err) {
      Logger.warn('AuthStore', `reload failed: ${(err as Error).message}`);
      this.cachedAuth = null;
    }
  }

  async save(auth: SavedAuth): Promise<void> {
    await this.ensureReady();
    if (this.store === null) {
      throw new Error('AuthStore not ready');
    }
    try {
      await this.store.put(KEY_SERVER_URL, auth.remoteServerUrl);
      await this.store.put(KEY_REMOTE_SERVER_URL, auth.remoteServerUrl);
      await this.store.put(KEY_LOCAL_SERVER_URL, auth.localServerUrl ?? '');
      await this.store.put(KEY_ACTIVE_ENDPOINT, auth.activeEndpoint);
      await this.store.put(KEY_USERNAME, auth.username);
      await this.store.put(KEY_SALT, auth.salt);
      await this.store.put(KEY_TOKEN, auth.token);
      await this.store.flush();
    } catch (err) {
      throw new Error(`AuthStore save failed: ${(err as Error).message}`);
    }
    this.cachedAuth = {
      remoteServerUrl: auth.remoteServerUrl,
      localServerUrl: auth.localServerUrl,
      activeEndpoint: auth.activeEndpoint,
      username: auth.username,
      salt: auth.salt,
      token: auth.token,
      authMode: auth.authMode ?? 'subsonicToken'
    };
  }

  async rememberLoginInfo(info: RememberedLoginInfo): Promise<void> {
    await this.ensureReady();
    if (this.store === null) {
      return;
    }
    try {
      await this.store.put(KEY_LAST_REMOTE_SERVER_URL, info.remoteServerUrl);
      await this.store.put(KEY_LAST_LOCAL_SERVER_URL, info.localServerUrl);
      await this.store.put(KEY_LAST_USERNAME, info.username);
      await this.store.put(KEY_LAST_PASSWORD, info.password);
      await this.store.flush();
    } catch (err) {
      Logger.warn('AuthStore', `rememberLoginInfo failed: ${(err as Error).message}`);
    }
  }

  async getRememberedLoginInfo(): Promise<RememberedLoginInfo> {
    await this.ensureReady();
    if (this.store === null) {
      return {
        remoteServerUrl: '',
        localServerUrl: '',
        username: '',
        password: ''
      };
    }
    try {
      const remoteServerUrl: string = (await this.store.get(KEY_LAST_REMOTE_SERVER_URL, '')) as string;
      const localServerUrl: string = (await this.store.get(KEY_LAST_LOCAL_SERVER_URL, '')) as string;
      const username: string = (await this.store.get(KEY_LAST_USERNAME, '')) as string;
      const password: string = (await this.store.get(KEY_LAST_PASSWORD, '')) as string;
      return {
        remoteServerUrl,
        localServerUrl,
        username,
        password
      };
    } catch (err) {
      Logger.warn('AuthStore', `getRememberedLoginInfo failed: ${(err as Error).message}`);
      return {
        remoteServerUrl: '',
        localServerUrl: '',
        username: '',
        password: ''
      };
    }
  }

  async isLocalUrlPersistedInSession(): Promise<boolean> {
    await this.ensureReady();
    if (this.store === null) {
      return true;
    }
    try {
      const rememberedLocalUrl: string = (await this.store.get(KEY_LAST_LOCAL_SERVER_URL, '')) as string;
      if (rememberedLocalUrl.trim().length === 0) {
        return true;
      }
      if (this.cachedAuth === null) {
        return false;
      }
      const sessionLocalUrl: string = this.cachedAuth.localServerUrl ?? '';
      return sessionLocalUrl.trim().length > 0;
    } catch (err) {
      Logger.warn('AuthStore', `isLocalUrlPersistedInSession failed: ${(err as Error).message}`);
      return true;
    }
  }

  async clear(keepRememberedLoginInfo: boolean = true): Promise<void> {
    await this.ensureReady();
    if (this.store !== null) {
      try {
        await this.store.delete(KEY_SERVER_URL);
        await this.store.delete(KEY_REMOTE_SERVER_URL);
        await this.store.delete(KEY_LOCAL_SERVER_URL);
        await this.store.delete(KEY_ACTIVE_ENDPOINT);
        await this.store.delete(KEY_USERNAME);
        await this.store.delete(KEY_SALT);
        await this.store.delete(KEY_TOKEN);
        if (!keepRememberedLoginInfo) {
          await this.store.delete(KEY_LAST_REMOTE_SERVER_URL);
          await this.store.delete(KEY_LAST_LOCAL_SERVER_URL);
          await this.store.delete(KEY_LAST_USERNAME);
          await this.store.delete(KEY_LAST_PASSWORD);
        }
        await this.store.flush();
      } catch (err) {
        Logger.warn('AuthStore', `clear failed: ${(err as Error).message}`);
      }
    }
    this.cachedAuth = null;
  }

  getCredentials(): SavedAuth | null {
    return this.cachedAuth;
  }

  getActiveEndpoint(): EndpointType {
    if (this.cachedAuth === null) {
      return 'remote';
    }
    return this.cachedAuth.activeEndpoint;
  }

  getActiveServerUrl(): string | null {
    if (this.cachedAuth === null) {
      return null;
    }
    return AuthStore.resolveEndpointUrl(this.cachedAuth, this.cachedAuth.activeEndpoint);
  }

  hasLocalServerUrl(): boolean {
    if (this.cachedAuth === null) {
      return false;
    }
    return this.cachedAuth.localServerUrl !== undefined && this.cachedAuth.localServerUrl.length > 0;
  }

  async setActiveEndpoint(endpoint: EndpointType): Promise<void> {
    if (this.cachedAuth === null) {
      return;
    }
    let nextEndpoint: EndpointType = endpoint;
    if (nextEndpoint === 'local' && !this.hasLocalServerUrl()) {
      nextEndpoint = 'remote';
    }
    this.cachedAuth.activeEndpoint = nextEndpoint;
    await this.ensureReady();
    if (this.store !== null) {
      try {
        await this.store.put(KEY_ACTIVE_ENDPOINT, nextEndpoint);
        await this.store.flush();
      } catch (err) {
        Logger.warn('AuthStore', `setActiveEndpoint failed: ${(err as Error).message}`);
      }
    }
  }

  isLoggedIn(): boolean {
    return this.cachedAuth !== null;
  }
}
