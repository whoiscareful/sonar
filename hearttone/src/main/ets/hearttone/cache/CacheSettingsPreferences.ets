import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Logger } from '../common/Logger';
import { CacheAutoModeUtil } from './CacheAutoModeUtil';
import { AutoCacheMode, CacheLimitGb } from './SongCacheTypes';

export interface CacheSettingsPublishHooks {
  publishLimitGb(limitGb: CacheLimitGb): void;
  publishAutoCacheMode(mode: AutoCacheMode): void;
}

/** Preferences 读写 + 规范化，音乐/封面缓存设置 Store 共用 */
export class CacheSettingsPreferences {
  private store: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private autoCacheMode: AutoCacheMode = 'wifi_only';
  private limitGb: CacheLimitGb = 2;
  private readonly storeName: string;
  private readonly logTag: string;
  private readonly hooks: CacheSettingsPublishHooks;

  constructor(storeName: string, logTag: string, hooks: CacheSettingsPublishHooks) {
    this.storeName = storeName;
    this.logTag = logTag;
    this.hooks = hooks;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store !== null) {
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, { name: this.storeName });
      await this.reload();
    } catch (err) {
      Logger.error(this.logTag, `init failed: ${(err as Error).message}`);
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
      const modeRaw: string = (await this.store.get('auto_cache_mode', 'wifi_only')) as string;
      this.autoCacheMode = CacheAutoModeUtil.normalizeMode(modeRaw);
      const limitRaw: number = (await this.store.get('limit_gb', 2)) as number;
      this.limitGb = CacheAutoModeUtil.normalizeLimitGb(limitRaw);
      this.hooks.publishLimitGb(this.limitGb);
      this.hooks.publishAutoCacheMode(this.autoCacheMode);
    } catch (err) {
      Logger.warn(this.logTag, `reload failed: ${(err as Error).message}`);
      this.autoCacheMode = 'wifi_only';
      this.limitGb = 2;
    }
  }

  getAutoCacheMode(): AutoCacheMode {
    return this.autoCacheMode;
  }

  getLimitGb(): CacheLimitGb {
    return this.limitGb;
  }

  getLimitBytes(): number {
    return this.limitGb * 1024 * 1024 * 1024;
  }

  async setAutoCacheMode(mode: AutoCacheMode): Promise<void> {
    await this.ensureReady();
    if (this.store === null) {
      return;
    }
    this.autoCacheMode = mode;
    try {
      await this.store.put('auto_cache_mode', mode);
      await this.store.flush();
    } catch (err) {
      Logger.warn(this.logTag, `setAutoCacheMode failed: ${(err as Error).message}`);
      return;
    }
    this.hooks.publishAutoCacheMode(mode);
  }

  async setLimitGb(limitGb: CacheLimitGb): Promise<void> {
    await this.ensureReady();
    if (this.store === null) {
      return;
    }
    this.limitGb = limitGb;
    try {
      await this.store.put('limit_gb', limitGb);
      await this.store.flush();
    } catch (err) {
      Logger.warn(this.logTag, `setLimitGb failed: ${(err as Error).message}`);
      return;
    }
    this.hooks.publishLimitGb(limitGb);
  }
}
