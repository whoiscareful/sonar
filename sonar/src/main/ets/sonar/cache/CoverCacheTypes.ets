export interface CoverCacheEntry {
  coverArtId: string;
  fileName: string;
  sizeBytes: number;
  lastAccessedAt: number;
  completedAt: number;
}

export interface CoverCacheIndex {
  entries: CoverCacheEntry[];
}
