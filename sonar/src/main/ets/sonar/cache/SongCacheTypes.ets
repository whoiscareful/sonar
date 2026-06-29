export type AutoCacheMode = 'off' | 'always' | 'wifi_only';

export type CacheLimitGb = 1 | 2 | 5 | 10;

export interface SongCacheEntry {
  songId: string;
  fileName: string;
  sizeBytes: number;
  lastAccessedAt: number;
  completedAt: number;
}

export interface SongCacheIndex {
  entries: SongCacheEntry[];
}
