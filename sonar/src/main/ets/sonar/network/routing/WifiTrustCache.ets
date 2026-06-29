import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Logger } from '../../common/Logger';

const STORE_NAME: string = 'sonar_wifi_trust';
const KEY_CACHE_JSON: string = 'wifi_trust_cache';
const TTL_MS: number = 30 * 24 * 60 * 60 * 1000;

interface WifiTrustEntry {
  lastSuccessMs: number;
}

type WifiTrustMap = Record<string, WifiTrustEntry>;

export class WifiTrustCache {
  private static store: preferences.Preferences | null = null;
  private static memoryCache: WifiTrustMap = {};

  static async init(context: common.Context): Promise<void> {
    if (WifiTrustCache.store !== null) {
      return;
    }
    try {
      WifiTrustCache.store = await preferences.getPreferences(context, { name: STORE_NAME });
      await WifiTrustCache.loadFromStore();
      await WifiTrustCache.purgeExpired();
    } catch (err) {
      Logger.warn('WifiTrustCache', `init failed: ${(err as Error).message}`);
    }
  }

  static isTrusted(ssid: string): boolean {
    if (ssid.length === 0) {
      return false;
    }
    const entry: WifiTrustEntry | undefined = WifiTrustCache.memoryCache[ssid];
    if (entry === undefined) {
      return false;
    }
    return Date.now() - entry.lastSuccessMs <= TTL_MS;
  }

  static async recordLocalSuccess(ssid: string): Promise<void> {
    if (ssid.length === 0) {
      return;
    }
    const entry: WifiTrustEntry = { lastSuccessMs: Date.now() };
    WifiTrustCache.memoryCache[ssid] = entry;
    await WifiTrustCache.persist();
  }

  static async remove(ssid: string): Promise<void> {
    if (ssid.length === 0) {
      return;
    }
    WifiTrustCache.memoryCache = WifiTrustCache.copyMapWithoutKey(WifiTrustCache.memoryCache, ssid);
    await WifiTrustCache.persist();
  }

  static async purgeExpired(): Promise<void> {
    const now: number = Date.now();
    const keys: string[] = Object.keys(WifiTrustCache.memoryCache);
    const next: WifiTrustMap = {};
    let changed: boolean = false;
    for (let i: number = 0; i < keys.length; i++) {
      const key: string = keys[i];
      const entry: WifiTrustEntry | undefined = WifiTrustCache.memoryCache[key];
      if (entry !== undefined && now - entry.lastSuccessMs <= TTL_MS) {
        next[key] = entry;
      } else {
        changed = true;
      }
    }
    if (changed) {
      WifiTrustCache.memoryCache = next;
      await WifiTrustCache.persist();
    }
  }

  private static copyMapWithoutKey(source: WifiTrustMap, excludedKey: string): WifiTrustMap {
    const next: WifiTrustMap = {};
    const keys: string[] = Object.keys(source);
    for (let i: number = 0; i < keys.length; i++) {
      const key: string = keys[i];
      if (key === excludedKey) {
        continue;
      }
      const entry: WifiTrustEntry | undefined = source[key];
      if (entry !== undefined) {
        next[key] = entry;
      }
    }
    return next;
  }

  private static async loadFromStore(): Promise<void> {
    if (WifiTrustCache.store === null) {
      return;
    }
    try {
      const raw: string = (await WifiTrustCache.store.get(KEY_CACHE_JSON, '{}')) as string;
      const parsed: Object = JSON.parse(raw);
      WifiTrustCache.memoryCache = parsed as WifiTrustMap;
    } catch (err) {
      Logger.warn('WifiTrustCache', `load failed: ${(err as Error).message}`);
      WifiTrustCache.memoryCache = {};
    }
  }

  private static async persist(): Promise<void> {
    if (WifiTrustCache.store === null) {
      return;
    }
    try {
      await WifiTrustCache.store.put(KEY_CACHE_JSON, JSON.stringify(WifiTrustCache.memoryCache));
      await WifiTrustCache.store.flush();
    } catch (err) {
      Logger.warn('WifiTrustCache', `persist failed: ${(err as Error).message}`);
    }
  }
}
