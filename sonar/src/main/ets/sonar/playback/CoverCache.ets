import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { EndpointType } from '../auth/AuthStore';
import { CacheFileUri } from '../common/CacheFileUri';
import { CacheFileUtil } from '../common/CacheFileUtil';
import { Logger } from '../common/Logger';
import { CacheAutoModeUtil } from '../cache/CacheAutoModeUtil';
import { CacheDownloadQueue } from '../cache/CacheDownloadQueue';
import { CacheEvictionUtil } from '../cache/CacheEvictionUtil';
import { CachePersistScheduler } from '../cache/CachePersistScheduler';
import { CoverCacheSettingsStore } from '../cache/CoverCacheSettingsStore';
import { CoverCacheStore } from '../cache/CoverCacheStore';
import { CoverCacheEntry, CoverCacheIndex } from '../cache/CoverCacheTypes';
import { AuthContext } from '../network/auth/AuthContext';
import { MediaResourceService } from '../network/media/MediaResourceService';
import { HttpTransport } from '../network/transport/HttpTransport';
import { TaskPoolRunner } from '../concurrency/TaskPoolRunner';
import { ReconcileEntryInput, ReconcileFileStat, ReconcileOrphanOutput } from '../concurrency/CacheIndexReconcileTask';
import { CoverDecodeScheduler, CoverDecodePriority } from './CoverDecodeScheduler';

const COVER_PIXEL_SIZE: number = 320;
const COVER_DISK_SIZE: number = 480;
const MAX_MEMORY_CACHE: number = 32;
const COVER_DIR: string = 'sonar_cover';
const INDEX_FILE: string = 'index.json';
const FILE_EXT: string = '.jpg';
const MIN_COMPLETE_BYTES: number = 1024;
const MAX_DOWNLOAD_ATTEMPTS: number = 2;

export class CoverDisplaySource {
  readonly pixelMap: image.PixelMap | null;
  readonly revision: number;

  constructor(pixelMap: image.PixelMap | null, revision: number) {
    this.pixelMap = pixelMap;
    this.revision = revision;
  }
}

interface CoverMemoryEntry {
  pixelMap: image.PixelMap;
}

export class CoverCache {
  private static context: common.UIAbilityContext | null = null;
  private static entryMap: Map<string, CoverCacheEntry> = new Map<string, CoverCacheEntry>();
  private static memoryCache: Map<string, CoverMemoryEntry> = new Map<string, CoverMemoryEntry>();
  private static memoryOrder: string[] = [];
  private static pixelLoadInFlight: Map<string, Promise<image.PixelMap | null>> =
    new Map<string, Promise<image.PixelMap | null>>();
  private static diskDownloadInFlight: Map<string, Promise<void>> = new Map<string, Promise<void>>();
  private static revision: number = 0;
  private static pinnedCoverArtId: string = '';
  private static readonly downloadQueue: CacheDownloadQueue = new CacheDownloadQueue();
  private static readonly persistScheduler: CachePersistScheduler = new CachePersistScheduler();
  private static safeIdToCoverArtId: Map<string, string> = new Map<string, string>();

  static setContext(context: common.UIAbilityContext): void {
    CoverCache.context = context;
  }

  static async init(): Promise<void> {
    if (CoverCache.context === null) {
      return;
    }
    CoverDecodeScheduler.setDecodeFn((path: string): Promise<image.PixelMap | null> => {
      return CoverCache.decodeFile(path);
    });
    CoverCacheStore.ensureInitialized();
    await CoverCacheSettingsStore.getInstance().init(CoverCache.context);
    CoverCache.ensureCoverDir();
    await CoverCache.loadIndex();
    CoverCache.publishUsageState();
    const settings: CoverCacheSettingsStore = CoverCacheSettingsStore.getInstance();
    CoverCacheStore.publishLimitGb(settings.getLimitGb());
    CoverCacheStore.publishAutoCacheMode(settings.getAutoCacheMode());
  }

  static getRevision(): number {
    return CoverCache.revision;
  }

  static shouldAutoCacheNow(): boolean {
    return CacheAutoModeUtil.shouldAutoCacheNow(
      CoverCacheSettingsStore.getInstance().getAutoCacheMode()
    );
  }

  static isComplete(coverArtId: string): boolean {
    return CoverCache.peekLocalPath(coverArtId) !== null;
  }

  /** 只读探测，不更新 LRU（热路径入队判断用） */
  static peekLocalPath(coverArtId: string): string | null {
    if (coverArtId.length === 0) {
      return null;
    }
    const entry: CoverCacheEntry | undefined = CoverCache.findEntryForCoverArtId(coverArtId);
    if (entry === undefined || entry.completedAt <= 0) {
      return null;
    }
    const path: string = CoverCache.entryPath(entry);
    if (!CacheFileUtil.fileExists(path)) {
      return null;
    }
    return path;
  }

  static resolveLocalPath(coverArtId: string): string | null {
    const path: string | null = CoverCache.peekLocalPath(coverArtId);
    if (path === null) {
      return null;
    }
    const entry: CoverCacheEntry | undefined = CoverCache.findEntryForCoverArtId(coverArtId);
    if (entry !== undefined) {
      entry.lastAccessedAt = Date.now();
      CoverCache.schedulePersistIndex();
    }
    return path;
  }

  static resolveDisplayUrl(coverArtId: string, displaySize: number): string | undefined {
    if (coverArtId.length === 0) {
      return undefined;
    }
    const localPath: string | null = CoverCache.resolveLocalPath(coverArtId);
    if (localPath !== null) {
      return CacheFileUri.fromAbsolutePath(localPath);
    }
    return MediaResourceService.buildCoverDisplayUrl(coverArtId, displaySize);
  }

  static maybeEnqueue(coverArtId: string): void {
    if (coverArtId.length === 0 || !CoverCache.shouldAutoCacheNow()) {
      return;
    }
    void CoverCache.enqueueDownload(coverArtId);
  }

  static async enqueueDownload(coverArtId: string): Promise<void> {
    if (coverArtId.length === 0 || CoverCache.isComplete(coverArtId)) {
      return;
    }
    if (!CoverCache.downloadQueue.enqueue(coverArtId)) {
      return;
    }
    void CoverCache.processQueue();
  }

  static getTotalSizeBytes(): number {
    return CacheEvictionUtil.sumCompletedSizeBytes(CoverCache.entryMap);
  }

  static getLimitBytes(): number {
    return CoverCacheSettingsStore.getInstance().getLimitBytes();
  }

  static touch(coverArtId: string): void {
    const entry: CoverCacheEntry | undefined = CoverCache.findEntryForCoverArtId(coverArtId);
    if (entry === undefined) {
      return;
    }
    entry.lastAccessedAt = Date.now();
    CoverCache.schedulePersistIndex();
  }

  static pin(coverArtId: string): void {
    if (coverArtId.length === 0) {
      return;
    }
    CoverCache.pinnedCoverArtId = coverArtId;
    CoverCache.touch(coverArtId);
    CoverCache.touchMemory(coverArtId);
  }

  static unpin(): void {
    CoverCache.pinnedCoverArtId = '';
  }

  static getDisplaySource(coverArtId: string): CoverDisplaySource {
    if (coverArtId.length === 0) {
      return new CoverDisplaySource(null, CoverCache.revision);
    }
    const entry: CoverMemoryEntry | undefined = CoverCache.memoryCache.get(coverArtId);
    if (entry !== undefined) {
      CoverCache.touchMemory(coverArtId);
      return new CoverDisplaySource(entry.pixelMap, CoverCache.revision);
    }
    return new CoverDisplaySource(null, CoverCache.revision);
  }

  static async load(coverArtId: string): Promise<image.PixelMap | null> {
    if (coverArtId.length === 0) {
      return null;
    }
    const cached: CoverMemoryEntry | undefined = CoverCache.memoryCache.get(coverArtId);
    if (cached !== undefined) {
      CoverCache.touchMemory(coverArtId);
      return cached.pixelMap;
    }
    const inFlight: Promise<image.PixelMap | null> | undefined =
      CoverCache.pixelLoadInFlight.get(coverArtId);
    if (inFlight !== undefined) {
      return await inFlight;
    }
    const task: Promise<image.PixelMap | null> = CoverCache.loadInternal(coverArtId);
    CoverCache.pixelLoadInFlight.set(coverArtId, task);
    try {
      return await task;
    } finally {
      CoverCache.pixelLoadInFlight.delete(coverArtId);
    }
  }

  static async releaseAll(): Promise<void> {
    const keys: string[] = Array.from(CoverCache.memoryCache.keys());
    for (let i: number = 0; i < keys.length; i++) {
      const entry: CoverMemoryEntry | undefined = CoverCache.memoryCache.get(keys[i]);
      if (entry !== undefined) {
        try {
          await entry.pixelMap.release();
        } catch (_err) {
        }
      }
    }
    CoverCache.memoryCache.clear();
    CoverCache.memoryOrder = [];
  }

  static async removeEntry(coverArtId: string, notifyUsage: boolean = true): Promise<void> {
    const entry: CoverCacheEntry | undefined = CoverCache.findEntryForCoverArtId(coverArtId);
    if (entry !== undefined) {
      CacheFileUtil.removeIfExists(CoverCache.entryPath(entry));
      CoverCache.safeIdToCoverArtId.delete(CoverCache.safeIdFromFileName(entry.fileName));
      CoverCache.entryMap.delete(entry.coverArtId);
    }
    CoverCache.evictMemory(coverArtId);
    await CoverCache.flushPersistIndex();
    if (notifyUsage) {
      CoverCache.publishUsageState();
      CoverCacheStore.bumpRevision();
    }
  }

  static async evictIfNeeded(): Promise<void> {
    const limitBytes: number = CoverCache.getLimitBytes();
    let evicted: boolean = false;
    while (CoverCache.getTotalSizeBytes() > limitBytes) {
      const victim: CoverCacheEntry | null = CacheEvictionUtil.pickOldestVictim(
        CoverCache.entryMap,
        CoverCache.pinnedCoverArtId,
        (entry: CoverCacheEntry): string => entry.coverArtId
      );
      if (victim === null) {
        break;
      }
      await CoverCache.removeEntry(victim.coverArtId, false);
      evicted = true;
      Logger.info('CoverCache', `evicted coverArtId=${victim.coverArtId}`);
    }
    if (evicted) {
      CoverCache.publishUsageState();
      CoverCacheStore.bumpRevision();
    }
  }

  private static findEntryForCoverArtId(coverArtId: string): CoverCacheEntry | undefined {
    const direct: CoverCacheEntry | undefined = CoverCache.entryMap.get(coverArtId);
    if (direct !== undefined) {
      return direct;
    }
    const safeQuery: string = CacheFileUtil.sanitizeId(coverArtId);
    const mappedId: string | undefined = CoverCache.safeIdToCoverArtId.get(safeQuery);
    if (mappedId !== undefined) {
      const mapped: CoverCacheEntry | undefined = CoverCache.entryMap.get(mappedId);
      if (mapped !== undefined) {
        return mapped;
      }
    }
    let matched: CoverCacheEntry | undefined = undefined;
    CoverCache.entryMap.forEach((entry: CoverCacheEntry) => {
      if (matched !== undefined) {
        return;
      }
      if (CacheFileUtil.sanitizeId(entry.coverArtId) === safeQuery) {
        matched = entry;
        return;
      }
      if (CoverCache.safeIdFromFileName(entry.fileName) === safeQuery) {
        matched = entry;
      }
    });
    return matched;
  }

  private static publishUsageState(): void {
    CoverCacheStore.publishUsedBytes(CoverCache.getTotalSizeBytes());
  }

  private static async loadInternal(coverArtId: string): Promise<image.PixelMap | null> {
    const localPath: string | null = CoverCache.resolveLocalPath(coverArtId);
    if (localPath !== null) {
      const pm: image.PixelMap | null =
        await CoverCache.scheduleDecode(coverArtId, localPath, CoverDecodePriority.PLAYBACK);
      if (pm !== null) {
        CoverCache.putMemory(coverArtId, pm);
        CoverCache.revision++;
      } else {
        await CoverCache.removeEntry(coverArtId, true);
      }
      return pm;
    }
    try {
      await CoverCache.ensureDownloaded(coverArtId);
      const pathAfter: string | null = CoverCache.resolveLocalPath(coverArtId);
      if (pathAfter === null) {
        return null;
      }
      const pm: image.PixelMap | null =
        await CoverCache.scheduleDecode(coverArtId, pathAfter, CoverDecodePriority.PLAYBACK);
      if (pm !== null) {
        CoverCache.putMemory(coverArtId, pm);
        CoverCache.revision++;
      }
      return pm;
    } catch (err) {
      Logger.warn('CoverCache', `load failed id=${coverArtId}: ${(err as Error).message}`);
      return null;
    }
  }

  private static async ensureDownloaded(coverArtId: string): Promise<void> {
    if (CoverCache.isComplete(coverArtId)) {
      return;
    }
    const inFlight: Promise<void> | undefined = CoverCache.diskDownloadInFlight.get(coverArtId);
    if (inFlight !== undefined) {
      await inFlight;
      return;
    }
    const task: Promise<void> = CoverCache.downloadOne(coverArtId);
    CoverCache.diskDownloadInFlight.set(coverArtId, task);
    try {
      await task;
    } finally {
      CoverCache.diskDownloadInFlight.delete(coverArtId);
    }
  }

  private static putMemory(coverArtId: string, pixelMap: image.PixelMap): void {
    if (CoverCache.memoryCache.has(coverArtId)) {
      CoverCache.memoryCache.delete(coverArtId);
      const idx: number = CoverCache.memoryOrder.indexOf(coverArtId);
      if (idx >= 0) {
        CoverCache.memoryOrder.splice(idx, 1);
      }
    }
    CoverCache.memoryCache.set(coverArtId, { pixelMap });
    CoverCache.memoryOrder.push(coverArtId);
    while (CoverCache.memoryOrder.length > MAX_MEMORY_CACHE) {
      const evictId: string | null = CoverCache.pickMemoryEvictCandidate();
      if (evictId === null) {
        break;
      }
      CoverCache.evictMemory(evictId);
    }
  }

  private static pickMemoryEvictCandidate(): string | null {
    for (let i: number = 0; i < CoverCache.memoryOrder.length; i++) {
      const id: string = CoverCache.memoryOrder[i];
      if (id !== CoverCache.pinnedCoverArtId) {
        return id;
      }
    }
    return null;
  }

  private static evictMemory(coverArtId: string): void {
    const idx: number = CoverCache.memoryOrder.indexOf(coverArtId);
    if (idx >= 0) {
      CoverCache.memoryOrder.splice(idx, 1);
    }
    const entry: CoverMemoryEntry | undefined = CoverCache.memoryCache.get(coverArtId);
    CoverCache.memoryCache.delete(coverArtId);
    if (entry !== undefined) {
      void entry.pixelMap.release();
    }
  }

  private static touchMemory(coverArtId: string): void {
    const idx: number = CoverCache.memoryOrder.indexOf(coverArtId);
    if (idx >= 0) {
      CoverCache.memoryOrder.splice(idx, 1);
      CoverCache.memoryOrder.push(coverArtId);
    }
  }

  private static schedulePersistIndex(): void {
    CoverCache.persistScheduler.schedulePersist((): Promise<void> => CoverCache.writeIndexFile());
  }

  private static async flushPersistIndex(): Promise<void> {
    await CoverCache.persistScheduler.flushPersist((): Promise<void> => CoverCache.writeIndexFile());
  }

  private static async processQueue(): Promise<void> {
    await CoverCache.downloadQueue.process(async (coverArtId: string): Promise<void> => {
      if (CoverCache.isComplete(coverArtId)) {
        return;
      }
      await CoverCache.ensureDownloaded(coverArtId);
    });
  }

  private static async downloadOne(coverArtId: string): Promise<void> {
    let lastError: string = '';
    for (let attempt: number = 1; attempt <= MAX_DOWNLOAD_ATTEMPTS; attempt++) {
      if (CoverCache.isComplete(coverArtId)) {
        return;
      }
      const safeId: string = CacheFileUtil.sanitizeId(coverArtId);
      const finalPath: string = CoverCache.buildFinalPath(safeId);
      try {
        await CoverCache.downloadToFile(coverArtId, finalPath);
        const sizeBytes: number = CacheFileUtil.fileSize(finalPath);
        if (sizeBytes < MIN_COMPLETE_BYTES) {
          CacheFileUtil.removeIfExists(finalPath);
          throw new Error(`cover file too small: ${sizeBytes}`);
        }
        await CoverCache.markComplete(coverArtId, safeId, sizeBytes);
        return;
      } catch (err) {
        lastError = (err as Error).message;
        Logger.warn('CoverCache',
          `download failed coverArtId=${coverArtId} attempt=${attempt}/${MAX_DOWNLOAD_ATTEMPTS}: ${lastError}`);
      }
    }
    Logger.error('CoverCache', `download exhausted coverArtId=${coverArtId}: ${lastError}`);
  }

  private static async markComplete(coverArtId: string, safeId: string, sizeBytes: number): Promise<void> {
    const now: number = Date.now();
    const fileName: string = `${safeId}${FILE_EXT}`;
    const entry: CoverCacheEntry = CoverCache.entryMap.get(coverArtId) ?? {
      coverArtId: coverArtId,
      fileName: fileName,
      sizeBytes: sizeBytes,
      lastAccessedAt: now,
      completedAt: now
    };
    entry.fileName = fileName;
    entry.sizeBytes = sizeBytes;
    entry.lastAccessedAt = now;
    entry.completedAt = now;
    CoverCache.entryMap.set(coverArtId, entry);
    CoverCache.safeIdToCoverArtId.set(safeId, coverArtId);
    await CoverCache.flushPersistIndex();
    await CoverCache.evictIfNeeded();
    CoverCache.publishUsageState();
    CoverCacheStore.bumpRevision();
    Logger.debug('CoverCache', `cached coverArtId=${coverArtId} size=${sizeBytes}`);
  }

  private static entryPath(entry: CoverCacheEntry): string {
    return `${CoverCache.coverDir()}/${entry.fileName}`;
  }

  private static buildFinalPath(safeId: string): string {
    return `${CoverCache.coverDir()}/${safeId}${FILE_EXT}`;
  }

  private static coverDir(): string {
    if (CoverCache.context === null) {
      return '';
    }
    return `${CoverCache.context.cacheDir}/${COVER_DIR}`;
  }

  private static indexPath(): string {
    return `${CoverCache.coverDir()}/${INDEX_FILE}`;
  }

  private static ensureCoverDir(): void {
    CacheFileUtil.ensureDir(CoverCache.coverDir());
  }

  private static safeIdFromFileName(fileName: string): string {
    if (fileName.endsWith(FILE_EXT)) {
      return fileName.substring(0, fileName.length - FILE_EXT.length);
    }
    return fileName;
  }

  private static scheduleDecode(
    coverArtId: string,
    path: string,
    priority: CoverDecodePriority = CoverDecodePriority.NORMAL
  ): Promise<image.PixelMap | null> {
    let effectivePriority: CoverDecodePriority = priority;
    if (coverArtId === CoverCache.pinnedCoverArtId) {
      effectivePriority = CoverDecodePriority.PINNED;
    }
    return CoverDecodeScheduler.schedule(coverArtId, path, effectivePriority);
  }

  private static async loadIndex(): Promise<void> {
    const path: string = CoverCache.indexPath();
    const text: string | null = CacheFileUtil.readTextFile(path);
    if (text === null) {
      CoverCache.entryMap.clear();
      CoverCache.safeIdToCoverArtId.clear();
    } else {
      try {
        const parsed: CoverCacheIndex = await TaskPoolRunner.parseJsonText<CoverCacheIndex>(text);
        const rawEntries: CoverCacheEntry[] = parsed.entries ?? [];
        CoverCache.entryMap.clear();
        CoverCache.safeIdToCoverArtId.clear();
        for (let i: number = 0; i < rawEntries.length; i++) {
          const raw: CoverCacheEntry = rawEntries[i] as CoverCacheEntry;
          if (raw.coverArtId === undefined || raw.fileName === undefined) {
            continue;
          }
          CoverCache.entryMap.set(raw.coverArtId, {
            coverArtId: raw.coverArtId,
            fileName: raw.fileName,
            sizeBytes: raw.sizeBytes ?? 0,
            lastAccessedAt: raw.lastAccessedAt ?? 0,
            completedAt: raw.completedAt ?? 0
          });
          CoverCache.safeIdToCoverArtId.set(
            CoverCache.safeIdFromFileName(raw.fileName),
            raw.coverArtId
          );
        }
      } catch (err) {
        Logger.warn('CoverCache', `loadIndex parse failed: ${(err as Error).message}`);
        CoverCache.entryMap.clear();
        CoverCache.safeIdToCoverArtId.clear();
      }
    }
    const reconciled: boolean = await CoverCache.reconcileIndexWithDisk();
    if (reconciled) {
      await CoverCache.flushPersistIndex();
    }
  }

  private static async reconcileIndexWithDisk(): Promise<boolean> {
    const entries: ReconcileEntryInput[] = [];
    CoverCache.entryMap.forEach((entry: CoverCacheEntry, coverArtId: string) => {
      entries.push({
        id: coverArtId,
        fileName: entry.fileName,
        sizeBytes: entry.sizeBytes,
        completedAt: entry.completedAt
      });
    });
    const diskFiles: ReconcileFileStat[] = CoverCache.collectDiskFileStats();
    const result = await TaskPoolRunner.reconcileCoverIndex(
      entries,
      diskFiles,
      MIN_COMPLETE_BYTES
    );
    let changed: boolean = false;
    for (let i: number = 0; i < result.deleteFiles.length; i++) {
      const fileName: string = result.deleteFiles[i];
      CacheFileUtil.removeIfExists(`${CoverCache.coverDir()}/${fileName}`);
      changed = true;
    }
    for (let j: number = 0; j < result.staleIds.length; j++) {
      const staleId: string = result.staleIds[j];
      const entry: CoverCacheEntry | undefined = CoverCache.entryMap.get(staleId);
      if (entry !== undefined) {
        CacheFileUtil.removeIfExists(CoverCache.entryPath(entry));
        CoverCache.safeIdToCoverArtId.delete(CoverCache.safeIdFromFileName(entry.fileName));
      }
      CoverCache.entryMap.delete(staleId);
      changed = true;
      Logger.info('CoverCache', `reconcile removed stale coverArtId=${staleId}`);
    }
    for (let k: number = 0; k < result.sizeUpdates.length; k++) {
      const update: ReconcileEntryInput = result.sizeUpdates[k];
      const entry: CoverCacheEntry | undefined = CoverCache.entryMap.get(update.id);
      if (entry !== undefined && entry.sizeBytes !== update.sizeBytes) {
        entry.sizeBytes = update.sizeBytes;
        changed = true;
      }
    }
    for (let m: number = 0; m < result.orphans.length; m++) {
      const orphan: ReconcileOrphanOutput = result.orphans[m];
      const now: number = Date.now();
      CoverCache.entryMap.set(orphan.coverArtId, {
        coverArtId: orphan.coverArtId,
        fileName: orphan.fileName,
        sizeBytes: orphan.sizeBytes,
        lastAccessedAt: now,
        completedAt: now
      });
      CoverCache.safeIdToCoverArtId.set(orphan.coverArtId, orphan.coverArtId);
      changed = true;
      Logger.info('CoverCache', `reconcile adopted orphan file=${orphan.fileName}`);
    }
    return changed;
  }

  private static collectDiskFileStats(): ReconcileFileStat[] {
    const fileNames: string[] = CoverCache.listJpgFilesOnDisk();
    const stats: ReconcileFileStat[] = [];
    const dir: string = CoverCache.coverDir();
    for (let i: number = 0; i < fileNames.length; i++) {
      const fileName: string = fileNames[i];
      stats.push({
        fileName: fileName,
        sizeBytes: CacheFileUtil.fileSize(`${dir}/${fileName}`)
      });
    }
    return stats;
  }

  private static listJpgFilesOnDisk(): string[] {
    const dir: string = CoverCache.coverDir();
    if (dir.length === 0) {
      return [];
    }
    try {
      const names: string[] = fileIo.listFileSync(dir);
      const result: string[] = [];
      for (let i: number = 0; i < names.length; i++) {
        const name: string = names[i];
        if (name.endsWith(FILE_EXT) && name !== INDEX_FILE) {
          result.push(name);
        }
      }
      return result;
    } catch (_err) {
      return [];
    }
  }

  private static async writeIndexFile(): Promise<void> {
    CoverCache.ensureCoverDir();
    const entries: CoverCacheEntry[] = [];
    CoverCache.entryMap.forEach((entry: CoverCacheEntry) => {
      entries.push(entry);
    });
    const text: string = JSON.stringify({ entries: entries });
    try {
      CacheFileUtil.writeTextAtomic(CoverCache.indexPath(), text);
    } catch (err) {
      Logger.warn('CoverCache', `writeIndex failed: ${(err as Error).message}`);
    }
  }

  private static async downloadToFile(coverArtId: string, localPath: string): Promise<void> {
    const content: ArrayBuffer = await HttpTransport.requestBufferWithFallback({
      buildUrl: (ep: EndpointType): string =>
        AuthContext.buildMediaUrl('getCoverArt',
          ['id', coverArtId, 'size', String(COVER_DISK_SIZE)], undefined, ep),
      profile: 'binarySmall'
    });
    CacheFileUtil.writeBufferAtomic(localPath, content);
  }

  private static async decodeFile(path: string): Promise<image.PixelMap | null> {
    try {
      const source: image.ImageSource = image.createImageSource(path);
      const pm: image.PixelMap = await source.createPixelMap({
        desiredSize: { width: COVER_PIXEL_SIZE, height: COVER_PIXEL_SIZE }
      });
      await source.release();
      return pm;
    } catch (err) {
      Logger.warn('CoverCache', `decode failed: ${(err as Error).message}`);
      return null;
    }
  }
}
