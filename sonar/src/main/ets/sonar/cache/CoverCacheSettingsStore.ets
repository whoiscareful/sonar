import { common } from '@kit.AbilityKit';
import { CoverCacheStore } from './CoverCacheStore';
import { CacheSettingsPreferences, CacheSettingsPublishHooks } from './CacheSettingsPreferences';
import { AutoCacheMode, CacheLimitGb } from './SongCacheTypes';

class CoverCachePublishHooks implements CacheSettingsPublishHooks {
  publishLimitGb(limitGb: CacheLimitGb): void {
    CoverCacheStore.publishLimitGb(limitGb);
  }

  publishAutoCacheMode(mode: AutoCacheMode): void {
    CoverCacheStore.publishAutoCacheMode(mode);
  }
}

export class CoverCacheSettingsStore {
  private static instance: CoverCacheSettingsStore | null = null;
  private readonly prefs: CacheSettingsPreferences;

  private constructor() {
    this.prefs = new CacheSettingsPreferences(
      'sonar_cover_cache',
      'CoverCacheSettingsStore',
      new CoverCachePublishHooks()
    );
  }

  static getInstance(): CoverCacheSettingsStore {
    if (CoverCacheSettingsStore.instance === null) {
      CoverCacheSettingsStore.instance = new CoverCacheSettingsStore();
    }
    return CoverCacheSettingsStore.instance;
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
