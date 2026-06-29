import { common } from '@kit.AbilityKit';
import { SongCacheStore } from './SongCacheStore';
import { CacheSettingsPreferences, CacheSettingsPublishHooks } from './CacheSettingsPreferences';
import { AutoCacheMode, CacheLimitGb } from './SongCacheTypes';

class SongCachePublishHooks implements CacheSettingsPublishHooks {
  publishLimitGb(limitGb: CacheLimitGb): void {
    SongCacheStore.publishLimitGb(limitGb);
  }

  publishAutoCacheMode(mode: AutoCacheMode): void {
    SongCacheStore.publishAutoCacheMode(mode);
  }
}

export class SongCacheSettingsStore {
  private static instance: SongCacheSettingsStore | null = null;
  private readonly prefs: CacheSettingsPreferences;

  private constructor() {
    this.prefs = new CacheSettingsPreferences(
      'sonar_song_cache',
      'SongCacheSettingsStore',
      new SongCachePublishHooks()
    );
  }

  static getInstance(): SongCacheSettingsStore {
    if (SongCacheSettingsStore.instance === null) {
      SongCacheSettingsStore.instance = new SongCacheSettingsStore();
    }
    return SongCacheSettingsStore.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    await this.prefs.init(context);
  }

  async ensureReady(): Promise<void> {
    await this.prefs.ensureReady();
  }

  getAutoCacheMode(): AutoCacheMode {
    return this.prefs.getAutoCacheMode();
  }

  getLimitGb(): CacheLimitGb {
    return this.prefs.getLimitGb();
  }

  getLimitBytes(): number {
    return this.prefs.getLimitBytes();
  }

  async setAutoCacheMode(mode: AutoCacheMode): Promise<void> {
    await this.prefs.setAutoCacheMode(mode);
  }

  async setLimitGb(limitGb: CacheLimitGb): Promise<void> {
    await this.prefs.setLimitGb(limitGb);
  }
}
