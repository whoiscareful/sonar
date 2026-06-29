import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { MusicListKind } from '../api/SubsonicTypes';
import { Logger } from '../common/Logger';

const STORE_NAME: string = 'sonar_music_tab';
const KEY_MUSIC_LIST_KIND: string = 'music_list_kind';
const DEFAULT_KIND: MusicListKind = 'random';

export class MusicTabSettingsStore {
  private static instance: MusicTabSettingsStore | null = null;
  private store: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private kind: MusicListKind = DEFAULT_KIND;

  private constructor() {
  }

  static getInstance(): MusicTabSettingsStore {
    if (MusicTabSettingsStore.instance === null) {
      MusicTabSettingsStore.instance = new MusicTabSettingsStore();
    }
    return MusicTabSettingsStore.instance;
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
      Logger.error('MusicTabSettingsStore', `init failed: ${(err as Error).message}`);
    }
  }

  async ensureReady(): Promise<void> {
    if (this.store !== null) {
      return;
    }
    if (this.context === null) {
      return;
    }
    await this.init(this.context);
  }

  private async reload(): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      const raw: string = (await this.store.get(KEY_MUSIC_LIST_KIND, DEFAULT_KIND)) as string;
      this.kind = MusicTabSettingsStore.normalizeKind(raw);
    } catch (err) {
      Logger.warn('MusicTabSettingsStore', `reload failed: ${(err as Error).message}`);
      this.kind = DEFAULT_KIND;
    }
  }

  getKind(): MusicListKind {
    return this.kind;
  }

  async setKind(kind: MusicListKind): Promise<void> {
    await this.ensureReady();
    if (this.store === null) {
      return;
    }
    this.kind = kind;
    try {
      await this.store.put(KEY_MUSIC_LIST_KIND, kind);
      await this.store.flush();
    } catch (err) {
      Logger.warn('MusicTabSettingsStore', `setKind failed: ${(err as Error).message}`);
    }
  }

  private static normalizeKind(raw: string): MusicListKind {
    if (raw === 'random' || raw === 'frequent' || raw === 'recent' || raw === 'newest') {
      return raw;
    }
    return DEFAULT_KIND;
  }
}
