import { AutoCacheMode, CacheLimitGb } from './SongCacheTypes';
import { SongCacheStore } from './SongCacheStore';

const KEY_USED_BYTES: string = 'coverCacheUsedBytes';
const KEY_LIMIT_GB: string = 'coverCacheLimitGb';
const KEY_AUTO_CACHE_MODE: string = 'coverCacheAutoMode';
const KEY_REVISION: string = 'coverCacheRevision';

/** 封面缓存用量 AppStorage 单源，UI 通过 @StorageLink 订阅 */
export class CoverCacheStore {
  static ensureInitialized(): void {
    if (AppStorage.get<number>(KEY_USED_BYTES) === undefined) {
      AppStorage.setOrCreate<number>(KEY_USED_BYTES, 0);
    }
    if (AppStorage.get<number>(KEY_LIMIT_GB) === undefined) {
      AppStorage.setOrCreate<number>(KEY_LIMIT_GB, 2);
    }
    if (AppStorage.get<string>(KEY_AUTO_CACHE_MODE) === undefined) {
      AppStorage.setOrCreate<string>(KEY_AUTO_CACHE_MODE, 'wifi_only');
    }
    if (AppStorage.get<number>(KEY_REVISION) === undefined) {
      AppStorage.setOrCreate<number>(KEY_REVISION, 0);
    }
  }

  static getUsedBytes(): number {
    const value: number | undefined = AppStorage.get<number>(KEY_USED_BYTES);
    return value ?? 0;
  }

  static getLimitGb(): number {
    const value: number | undefined = AppStorage.get<number>(KEY_LIMIT_GB);
    return value ?? 2;
  }

  static getRevision(): number {
    const value: number | undefined = AppStorage.get<number>(KEY_REVISION);
    return value ?? 0;
  }

  static publishUsedBytes(bytes: number): void {
    CoverCacheStore.ensureInitialized();
    AppStorage.setOrCreate<number>(KEY_USED_BYTES, bytes);
  }

  static publishLimitGb(limitGb: CacheLimitGb): void {
    CoverCacheStore.ensureInitialized();
    AppStorage.setOrCreate<number>(KEY_LIMIT_GB, limitGb);
  }

  static getAutoCacheMode(): AutoCacheMode {
    const value: string | undefined = AppStorage.get<string>(KEY_AUTO_CACHE_MODE);
    if (value === 'off' || value === 'always' || value === 'wifi_only') {
      return value;
    }
    return 'wifi_only';
  }

  static publishAutoCacheMode(mode: AutoCacheMode): void {
    CoverCacheStore.ensureInitialized();
    AppStorage.setOrCreate<string>(KEY_AUTO_CACHE_MODE, mode);
  }

  static bumpRevision(): void {
    CoverCacheStore.ensureInitialized();
    const current: number = CoverCacheStore.getRevision();
    AppStorage.setOrCreate<number>(KEY_REVISION, current + 1);
  }

  static formatBytes(bytes: number): string {
    return SongCacheStore.formatBytes(bytes);
  }
}
