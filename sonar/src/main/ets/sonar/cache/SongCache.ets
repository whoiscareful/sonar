import { common } from '@kit.AbilityKit';
import { CacheFileUtil } from '../common/CacheFileUtil';
import { Logger } from '../common/Logger';
import { CacheAutoModeUtil } from './CacheAutoModeUtil';
import { CacheDownloadQueue } from './CacheDownloadQueue';
import { CacheEvictionUtil } from './CacheEvictionUtil';
import { CachePersistScheduler } from './CachePersistScheduler';
import { SongCacheSettingsStore } from './SongCacheSettingsStore';
import { SongCacheStore } from './SongCacheStore';
import { SongCacheWriter } from './SongCacheWriter';
import { SongCacheEntry, SongCacheIndex } from './SongCacheTypes';
import { TaskPoolRunner } from '../concurrency/TaskPoolRunner';
import { ReconcileEntryInput, ReconcileFileStat } from '../concurrency/CacheIndexReconcileTask';

const AUDIO_DIR: string = 'sonar_audio';
const INDEX_FILE: string = 'index.json';
const DEFAULT_EXT: string = '.mp3';
const MIN_COMPLETE_BYTES: number = 4096;
const MAX_DOWNLOAD_ATTEMPTS: number = 2;

export class SongCache {
  private static context: common.UIAbilityContext | null = null;
  private static entryMap: Map<string, SongCacheEntry> = new Map<string, SongCacheEntry>();
  private static pinnedSongId: string = '';
  private static readonly writer: SongCacheWriter = new SongCacheWriter();
  private static readonly downloadQueue: CacheDownloadQueue = new CacheDownloadQueue();
  private static readonly persistScheduler: CachePersistScheduler = new CachePersistScheduler();

  static setContext(context: common.UIAbilityContext): void {
    SongCache.context = context;
  }

  static async init(): Promise<void> {
    if (SongCache.context === null) {
      return;
    }
    await SongCacheSettingsStore.getInstance().init(SongCache.context);
    SongCache.ensureAudioDir();
    await SongCache.loadIndex();
    SongCache.publishUsageState();
    const settings: SongCacheSettingsStore = SongCacheSettingsStore.getInstance();
    SongCacheStore.publishLimitGb(settings.getLimitGb());
    SongCacheStore.publishAutoCacheMode(settings.getAutoCacheMode());
  }

  static isComplete(songId: string): boolean {
    return SongCache.resolveLocalPath(songId) !== null;
  }

  static resolveLocalPath(songId: string): string | null {
    const entry: SongCacheEntry | undefined = SongCache.entryMap.get(songId);
    if (entry === undefined || entry.completedAt <= 0) {
      return null;
    }
    const path: string = SongCache.entryPath(entry);
    if (!CacheFileUtil.fileExists(path)) {
      return null;
    }
    entry.lastAccessedAt = Date.now();
    SongCache.schedulePersistIndex();
    return path;
  }

  static getTotalSizeBytes(): number {
    return CacheEvictionUtil.sumCompletedSizeBytes(SongCache.entryMap);
  }

  static getLimitBytes(): number {
    return SongCacheSettingsStore.getInstance().getLimitBytes();
  }

  static shouldAutoCacheNow(): boolean {
    return CacheAutoModeUtil.shouldAutoCacheNow(
      SongCacheSettingsStore.getInstance().getAutoCacheMode()
    );
  }

  static touch(songId: string): void {
    const entry: SongCacheEntry | undefined = SongCache.entryMap.get(songId);
    if (entry === undefined) {
      return;
    }
    entry.lastAccessedAt = Date.now();
    SongCache.schedulePersistIndex();
  }

  static pin(songId: string): void {
    if (songId.length === 0) {
      return;
    }
    SongCache.pinnedSongId = songId;
    SongCache.touch(songId);
  }

  static unpin(): void {
    SongCache.pinnedSongId = '';
  }

  static cancelActiveDownload(songId?: string): void {
    SongCache.writer.cancel(songId);
    if (songId !== undefined && songId.length > 0) {
      SongCache.downloadQueue.remove(songId);
    }
  }

  static async enqueueDownload(songId: string): Promise<void> {
    if (songId.length === 0) {
      return;
    }
    if (SongCache.isComplete(songId)) {
      return;
    }
    if (SongCache.writer.isBusy() && SongCache.writer.getActiveSongId() === songId) {
      return;
    }
    if (!SongCache.downloadQueue.enqueue(songId)) {
      return;
    }
    void SongCache.processQueue();
  }

  static async removeEntry(songId: string, notifyUsage: boolean = true): Promise<void> {
    const entry: SongCacheEntry | undefined = SongCache.entryMap.get(songId);
    if (entry !== undefined) {
      CacheFileUtil.removeIfExists(SongCache.entryPath(entry));
      CacheFileUtil.removeIfExists(SongCache.partPathForEntry(entry));
    }
    SongCache.entryMap.delete(songId);
    await SongCache.flushPersistIndex();
    if (notifyUsage) {
      SongCache.publishUsageState();
    }
  }

  static async evictIfNeeded(): Promise<void> {
    const limitBytes: number = SongCache.getLimitBytes();
    let evicted: boolean = false;
    while (SongCache.getTotalSizeBytes() > limitBytes) {
      const victim: SongCacheEntry | null = CacheEvictionUtil.pickOldestVictim(
        SongCache.entryMap,
        SongCache.pinnedSongId,
        (entry: SongCacheEntry): string => entry.songId
      );
      if (victim === null) {
        break;
      }
      await SongCache.removeEntry(victim.songId, false);
      evicted = true;
      Logger.info('SongCache', `evicted songId=${victim.songId}`);
    }
    if (evicted) {
      SongCache.publishUsageState();
    }
  }

  private static publishUsageState(): void {
    SongCacheStore.publishUsedBytes(SongCache.getTotalSizeBytes());
  }

  private static schedulePersistIndex(): void {
    SongCache.persistScheduler.schedulePersist((): Promise<void> => SongCache.writeIndexFile());
  }

  private static async flushPersistIndex(): Promise<void> {
    await SongCache.persistScheduler.flushPersist((): Promise<void> => SongCache.writeIndexFile());
  }

  private static async processQueue(): Promise<void> {
    await SongCache.downloadQueue.process(async (songId: string): Promise<void> => {
      if (SongCache.isComplete(songId)) {
        return;
      }
      await SongCache.downloadOne(songId);
    });
  }

  private static async downloadOne(songId: string): Promise<void> {
    let lastError: string = '';
    for (let attempt: number = 1; attempt <= MAX_DOWNLOAD_ATTEMPTS; attempt++) {
      if (SongCache.isComplete(songId)) {
        return;
      }
      const safeId: string = CacheFileUtil.sanitizeId(songId);
      const ext: string = DEFAULT_EXT;
      const partPath: string = SongCache.buildPartPath(safeId, ext);
      const finalPath: string = SongCache.buildFinalPath(safeId, ext);
      let completedSize: number = 0;
      try {
        await SongCache.writer.streamToFile(songId, partPath, finalPath, {
          onComplete: (sizeBytes: number): void => {
            completedSize = sizeBytes;
          },
          onError: (message: string): void => {
            lastError = message;
          }
        });
        await SongCache.markComplete(songId, safeId, ext, completedSize);
        return;
      } catch (err) {
        lastError = (err as Error).message;
        Logger.warn('SongCache',
          `download failed songId=${songId} attempt=${attempt}/${MAX_DOWNLOAD_ATTEMPTS}: ${lastError}`);
      }
    }
    Logger.error('SongCache', `download exhausted songId=${songId}: ${lastError}`);
  }

  private static async markComplete(
    songId: string,
    safeId: string,
    ext: string,
    sizeBytes: number
  ): Promise<void> {
    const now: number = Date.now();
    const fileName: string = `${safeId}${ext}`;
    const entry: SongCacheEntry = SongCache.entryMap.get(songId) ?? {
      songId: songId,
      fileName: fileName,
      sizeBytes: sizeBytes,
      lastAccessedAt: now,
      completedAt: now
    };
    entry.fileName = fileName;
    entry.sizeBytes = sizeBytes;
    entry.lastAccessedAt = now;
    entry.completedAt = now;
    SongCache.entryMap.set(songId, entry);
    await SongCache.flushPersistIndex();
    await SongCache.evictIfNeeded();
    SongCache.publishUsageState();
    Logger.debug('SongCache', `cached songId=${songId} size=${sizeBytes}`);
  }

  private static entryPath(entry: SongCacheEntry): string {
    return `${SongCache.audioDir()}/${entry.fileName}`;
  }

  private static partPathForEntry(entry: SongCacheEntry): string {
    return `${SongCache.entryPath(entry)}.part`;
  }

  private static buildPartPath(safeId: string, ext: string): string {
    return `${SongCache.audioDir()}/${safeId}${ext}.part`;
  }

  private static buildFinalPath(safeId: string, ext: string): string {
    return `${SongCache.audioDir()}/${safeId}${ext}`;
  }

  private static audioDir(): string {
    if (SongCache.context === null) {
      return '';
    }
    return `${SongCache.context.cacheDir}/${AUDIO_DIR}`;
  }

  private static indexPath(): string {
    return `${SongCache.audioDir()}/${INDEX_FILE}`;
  }

  private static ensureAudioDir(): void {
    CacheFileUtil.ensureDir(SongCache.audioDir());
  }

  private static async loadIndex(): Promise<void> {
    const path: string = SongCache.indexPath();
    const text: string | null = CacheFileUtil.readTextFile(path);
    if (text === null) {
      SongCache.entryMap.clear();
      return;
    }
    try {
      const parsed: SongCacheIndex = await TaskPoolRunner.parseJsonText<SongCacheIndex>(text);
      const rawEntries: SongCacheEntry[] = parsed.entries ?? [];
      SongCache.entryMap.clear();
      for (let i: number = 0; i < rawEntries.length; i++) {
        const raw: SongCacheEntry = rawEntries[i] as SongCacheEntry;
        if (raw.songId === undefined || raw.fileName === undefined) {
          continue;
        }
        SongCache.entryMap.set(raw.songId, {
          songId: raw.songId,
          fileName: raw.fileName,
          sizeBytes: raw.sizeBytes ?? 0,
          lastAccessedAt: raw.lastAccessedAt ?? 0,
          completedAt: raw.completedAt ?? 0
        });
      }
    } catch (err) {
      Logger.warn('SongCache', `loadIndex parse failed: ${(err as Error).message}`);
      SongCache.entryMap.clear();
    }
    const reconciled: boolean = await SongCache.reconcileIndexWithDisk();
    if (reconciled) {
      await SongCache.flushPersistIndex();
    }
  }

  /** 剔除索引中无对应文件的条目，并校正 sizeBytes */
  private static async reconcileIndexWithDisk(): Promise<boolean> {
    const entries: ReconcileEntryInput[] = [];
    SongCache.entryMap.forEach((entry: SongCacheEntry, songId: string) => {
      entries.push({
        id: songId,
        fileName: entry.fileName,
        sizeBytes: entry.sizeBytes,
        completedAt: entry.completedAt
      });
    });
    const diskFiles: ReconcileFileStat[] = SongCache.collectDiskFileStats();
    const result = await TaskPoolRunner.reconcileSongIndex(
      entries,
      diskFiles,
      MIN_COMPLETE_BYTES
    );
    let changed: boolean = false;
    for (let i: number = 0; i < result.staleIds.length; i++) {
      const staleId: string = result.staleIds[i];
      const entry: SongCacheEntry | undefined = SongCache.entryMap.get(staleId);
      if (entry !== undefined) {
        const path: string = SongCache.entryPath(entry);
        if (CacheFileUtil.fileExists(path)) {
          const actualSize: number = CacheFileUtil.fileSize(path);
          if (actualSize < MIN_COMPLETE_BYTES) {
            CacheFileUtil.removeIfExists(path);
          }
        }
      }
      SongCache.entryMap.delete(staleId);
      changed = true;
      Logger.info('SongCache', `reconcile removed stale songId=${staleId}`);
    }
    for (let j: number = 0; j < result.sizeUpdates.length; j++) {
      const update: ReconcileEntryInput = result.sizeUpdates[j];
      const entry: SongCacheEntry | undefined = SongCache.entryMap.get(update.id);
      if (entry !== undefined && entry.sizeBytes !== update.sizeBytes) {
        entry.sizeBytes = update.sizeBytes;
        changed = true;
      }
    }
    return changed;
  }

  private static collectDiskFileStats(): ReconcileFileStat[] {
    const stats: ReconcileFileStat[] = [];
    SongCache.entryMap.forEach((entry: SongCacheEntry) => {
      const path: string = SongCache.entryPath(entry);
      if (!CacheFileUtil.fileExists(path)) {
        return;
      }
      stats.push({
        fileName: entry.fileName,
        sizeBytes: CacheFileUtil.fileSize(path)
      });
    });
    return stats;
  }

  private static async writeIndexFile(): Promise<void> {
    SongCache.ensureAudioDir();
    const entries: SongCacheEntry[] = [];
    SongCache.entryMap.forEach((entry: SongCacheEntry) => {
      entries.push(entry);
    });
    const text: string = JSON.stringify({ entries: entries });
    try {
      CacheFileUtil.writeTextAtomic(SongCache.indexPath(), text);
    } catch (err) {
      Logger.warn('SongCache', `writeIndex failed: ${(err as Error).message}`);
    }
  }

  /** 本地文件损坏/缺失时才删缓存；播放器瞬时错误保留文件并回退 HTTP */
  static shouldInvalidateLocalCache(localPath: string, err: Error): boolean {
    if (!CacheFileUtil.fileExists(localPath)) {
      return true;
    }
    const size: number = CacheFileUtil.fileSize(localPath);
    if (size < MIN_COMPLETE_BYTES) {
      return true;
    }
    const message: string = err.message.toLowerCase();
    if (message.includes('no such file') ||
      message.includes('not found') ||
      message.includes('invalid fd') ||
      message.includes('corrupt') ||
      message.includes('unsupported') ||
      message.includes('format')) {
      return true;
    }
    return false;
  }
}
