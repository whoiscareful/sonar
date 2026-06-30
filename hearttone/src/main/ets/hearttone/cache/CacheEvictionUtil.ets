export interface CacheEvictableEntry {
  completedAt: number;
  lastAccessedAt: number;
}

export interface CacheSizedEntry extends CacheEvictableEntry {
  sizeBytes: number;
}

export class CacheEvictionUtil {
  static pickOldestVictim<T extends CacheEvictableEntry>(
    entries: Map<string, T>,
    pinnedId: string,
    getId: (entry: T) => string
  ): T | null {
    let oldest: T | null = null;
    entries.forEach((entry: T) => {
      if (entry.completedAt <= 0) {
        return;
      }
      if (getId(entry) === pinnedId) {
        return;
      }
      if (oldest === null || entry.lastAccessedAt < oldest.lastAccessedAt) {
        oldest = entry;
      }
    });
    return oldest;
  }

  static sumCompletedSizeBytes<T extends CacheSizedEntry>(
    entries: Map<string, T>
  ): number {
    let total: number = 0;
    entries.forEach((entry: T) => {
      if (entry.completedAt > 0) {
        total += entry.sizeBytes;
      }
    });
    return total;
  }
}
