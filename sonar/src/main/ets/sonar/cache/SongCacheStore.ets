import { AutoCacheMode, CacheLimitGb } from './SongCacheTypes';

const KEY_USED_BYTES: string = 'songCacheUsedBytes';
const KEY_LIMIT_GB: string = 'songCacheLimitGb';
const KEY_AUTO_CACHE_MODE: string = 'songCacheAutoMode';

/** 缓存用量 AppStorage 单源，UI 通过 @StorageLink 订阅 */
export class SongCacheStore {
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
  }

  static getUsedBytes(): number {
    const value: number | undefined = AppStorage.get<number>(KEY_USED_BYTES);
    return value ?? 0;
  }

  static getLimitGb(): number {
    const value: number | undefined = AppStorage.get<number>(KEY_LIMIT_GB);
    return value ?? 2;
  }

  static publishUsedBytes(bytes: number): void {
    SongCacheStore.ensureInitialized();
    AppStorage.setOrCreate<number>(KEY_USED_BYTES, bytes);
  }

  static publishLimitGb(limitGb: CacheLimitGb): void {
    SongCacheStore.ensureInitialized();
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
    SongCacheStore.ensureInitialized();
    AppStorage.setOrCreate<string>(KEY_AUTO_CACHE_MODE, mode);
  }

  static formatBytes(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} MB`;
    }
    if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }
}
