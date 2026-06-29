import { NetworkStatus } from '../common/NetworkStatus';
import { AutoCacheMode, CacheLimitGb } from './SongCacheTypes';

const DEFAULT_AUTO_CACHE_MODE: AutoCacheMode = 'wifi_only';
const DEFAULT_LIMIT_GB: CacheLimitGb = 2;

export class CacheAutoModeUtil {
  static shouldAutoCacheNow(mode: AutoCacheMode): boolean {
    if (mode === 'off') {
      return false;
    }
    if (mode === 'always') {
      return true;
    }
    return NetworkStatus.isOnWifi();
  }

  static normalizeMode(raw: string): AutoCacheMode {
    if (raw === 'off' || raw === 'always' || raw === 'wifi_only') {
      return raw;
    }
    return DEFAULT_AUTO_CACHE_MODE;
  }

  static normalizeLimitGb(raw: number): CacheLimitGb {
    if (raw === 1 || raw === 2 || raw === 5 || raw === 10) {
      return raw;
    }
    return DEFAULT_LIMIT_GB;
  }
}
