export interface ReconcileFileStat {
  fileName: string;
  sizeBytes: number;
}

export interface ReconcileEntryInput {
  id: string;
  fileName: string;
  sizeBytes: number;
  completedAt: number;
}

export interface ReconcileOrphanOutput {
  coverArtId: string;
  fileName: string;
  sizeBytes: number;
}

export interface CoverReconcileResult {
  staleIds: string[];
  orphans: ReconcileOrphanOutput[];
  sizeUpdates: ReconcileEntryInput[];
  deleteFiles: string[];
}

export interface SongReconcileResult {
  staleIds: string[];
  sizeUpdates: ReconcileEntryInput[];
}

@Concurrent
export function reconcileCoverIndexConcurrent(
  entries: ReconcileEntryInput[],
  diskFiles: ReconcileFileStat[],
  minCompleteBytes: number
): CoverReconcileResult {
  const staleIds: string[] = [];
  const sizeUpdates: ReconcileEntryInput[] = [];
  const knownSafeIds: Set<string> = new Set<string>();
  const deleteFiles: string[] = [];
  const jpgSuffix: string = '.jpg';

  for (let i: number = 0; i < entries.length; i++) {
    const entry: ReconcileEntryInput = entries[i];
    if (entry.completedAt <= 0) {
      staleIds.push(entry.id);
      continue;
    }
    let matchedSize: number = -1;
    for (let j: number = 0; j < diskFiles.length; j++) {
      if (diskFiles[j].fileName === entry.fileName) {
        matchedSize = diskFiles[j].sizeBytes;
        break;
      }
    }
    if (matchedSize < 0) {
      staleIds.push(entry.id);
      continue;
    }
    if (matchedSize < minCompleteBytes) {
      staleIds.push(entry.id);
      continue;
    }
    let safeId: string = entry.fileName;
    if (entry.fileName.endsWith(jpgSuffix)) {
      safeId = entry.fileName.substring(0, entry.fileName.length - 4);
    }
    knownSafeIds.add(safeId);
    if (entry.sizeBytes !== matchedSize) {
      sizeUpdates.push({
        id: entry.id,
        fileName: entry.fileName,
        sizeBytes: matchedSize,
        completedAt: entry.completedAt
      });
    }
  }

  const orphans: ReconcileOrphanOutput[] = [];
  for (let k: number = 0; k < diskFiles.length; k++) {
    const file: ReconcileFileStat = diskFiles[k];
    let safeId: string = file.fileName;
    if (file.fileName.endsWith(jpgSuffix)) {
      safeId = file.fileName.substring(0, file.fileName.length - 4);
    }
    if (knownSafeIds.has(safeId)) {
      continue;
    }
    if (file.sizeBytes < minCompleteBytes) {
      deleteFiles.push(file.fileName);
      continue;
    }
    orphans.push({
      coverArtId: safeId,
      fileName: file.fileName,
      sizeBytes: file.sizeBytes
    });
  }

  return { staleIds, orphans, sizeUpdates, deleteFiles };
}

@Concurrent
export function reconcileSongIndexConcurrent(
  entries: ReconcileEntryInput[],
  diskFiles: ReconcileFileStat[],
  minCompleteBytes: number
): SongReconcileResult {
  const staleIds: string[] = [];
  const sizeUpdates: ReconcileEntryInput[] = [];

  for (let i: number = 0; i < entries.length; i++) {
    const entry: ReconcileEntryInput = entries[i];
    if (entry.completedAt <= 0) {
      staleIds.push(entry.id);
      continue;
    }
    let matchedSize: number = -1;
    for (let j: number = 0; j < diskFiles.length; j++) {
      if (diskFiles[j].fileName === entry.fileName) {
        matchedSize = diskFiles[j].sizeBytes;
        break;
      }
    }
    if (matchedSize < 0) {
      staleIds.push(entry.id);
      continue;
    }
    if (matchedSize < minCompleteBytes) {
      staleIds.push(entry.id);
      continue;
    }
    if (entry.sizeBytes !== matchedSize) {
      sizeUpdates.push({
        id: entry.id,
        fileName: entry.fileName,
        sizeBytes: matchedSize,
        completedAt: entry.completedAt
      });
    }
  }

  return { staleIds, sizeUpdates };
}
