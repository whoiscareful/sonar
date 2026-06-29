import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AuthStore } from '../auth/AuthStore';
import { Logger } from '../common/Logger';
import { SubsonicUrlUtil } from '../network/api/SubsonicUrlUtil';

const STORE_NAME: string = 'sonar_recent_play';
const KEY_PREFIX: string = 'recent_play_';
const MAX_ENTRIES: number = 300;
const PERSIST_DEBOUNCE_MS: number = 400;
const RETENTION_MS: number = 30 * 24 * 60 * 60 * 1000;

interface RecentPlayEntry {
  songId: string;
  playedAt: number;
}

/** 最近播放索引：仅存 songId + playedAt，元数据由 SongMetadataCache 解析。 */
export class RecentPlayHistoryStore {
  private static instance: RecentPlayHistoryStore | null = null;
  private store: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private entries: RecentPlayEntry[] = [];
  private loadedAccountKey: string = '';
  private persistTimerId: number = -1;

  private constructor() {
  }

  static getInstance(): RecentPlayHistoryStore {
    if (RecentPlayHistoryStore.instance === null) {
      RecentPlayHistoryStore.instance = new RecentPlayHistoryStore();
    }
    return RecentPlayHistoryStore.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store !== null) {
      await this.ensureAccountLoaded();
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
      await this.ensureAccountLoaded();
    } catch (err) {
      Logger.error('RecentPlayHistoryStore', `init failed: ${(err as Error).message}`);
    }
  }

  async ensureReady(): Promise<void> {
    if (this.store !== null) {
      await this.ensureAccountLoaded();
      return;
    }
    if (this.context === null) {
      return;
    }
    await this.init(this.context);
  }

  async recordPlay(songId: string, playedAtMs: number): Promise<void> {
    await this.ensureReady();
    if (songId.length === 0 || this.loadedAccountKey.length === 0) {
      return;
    }
    const rest: RecentPlayEntry[] = this.entries.filter((entry: RecentPlayEntry) => entry.songId !== songId);
    const next: RecentPlayEntry[] = [{ songId: songId, playedAt: playedAtMs }, ...rest];
    this.entries = RecentPlayHistoryStore.trimEntries(next, playedAtMs);
    this.schedulePersist();
  }

  async removeSong(songId: string): Promise<boolean> {
    await this.ensureReady();
    if (songId.length === 0 || this.loadedAccountKey.length === 0) {
      return false;
    }
    const before: number = this.entries.length;
    this.entries = this.entries.filter((entry: RecentPlayEntry) => entry.songId !== songId);
    if (this.entries.length === before) {
      return false;
    }
    this.schedulePersist();
    return true;
  }

  listSongIds(offset: number, limit: number): string[] {
    const before: number = this.entries.length;
    this.entries = RecentPlayHistoryStore.trimEntries(this.entries, Date.now());
    if (this.entries.length !== before && this.loadedAccountKey.length > 0) {
      this.schedulePersist();
    }
    const safeOffset: number = offset < 0 ? 0 : offset;
    const safeLimit: number = limit < 0 ? 0 : limit;
    const end: number = Math.min(safeOffset + safeLimit, this.entries.length);
    const result: string[] = [];
    for (let i: number = safeOffset; i < end; i++) {
      result.push(this.entries[i].songId);
    }
    return result;
  }

  totalCount(): number {
    return this.entries.length;
  }

  clearMemory(): void {
    if (this.persistTimerId >= 0) {
      clearTimeout(this.persistTimerId);
      this.persistTimerId = -1;
    }
    this.entries = [];
    this.loadedAccountKey = '';
  }

  private schedulePersist(): void {
    if (this.persistTimerId >= 0) {
      clearTimeout(this.persistTimerId);
    }
    this.persistTimerId = setTimeout(() => {
      this.persistTimerId = -1;
      void this.persist();
    }, PERSIST_DEBOUNCE_MS);
  }

  private async ensureAccountLoaded(): Promise<void> {
    const accountKey: string = RecentPlayHistoryStore.computeAccountKey();
    if (accountKey === this.loadedAccountKey) {
      return;
    }
    if (this.persistTimerId >= 0) {
      clearTimeout(this.persistTimerId);
      this.persistTimerId = -1;
    }
    this.loadedAccountKey = accountKey;
    this.entries = [];
    if (this.store === null || accountKey.length === 0) {
      return;
    }
    try {
      const raw: string = (await this.store.get(`${KEY_PREFIX}${accountKey}`, '[]')) as string;
      const parsed: RecentPlayEntry[] = JSON.parse(raw) as RecentPlayEntry[];
      if (!Array.isArray(parsed)) {
        this.entries = [];
        return;
      }
      const normalized: RecentPlayEntry[] = [];
      for (let i: number = 0; i < parsed.length; i++) {
        const item: RecentPlayEntry = parsed[i];
        if (item.songId !== undefined && item.songId.length > 0 && item.playedAt > 0) {
          normalized.push({ songId: item.songId, playedAt: item.playedAt });
        }
      }
      this.entries = RecentPlayHistoryStore.trimEntries(normalized, Date.now());
    } catch (err) {
      Logger.warn('RecentPlayHistoryStore', `load failed: ${(err as Error).message}`);
      this.entries = [];
    }
  }

  private async persist(): Promise<void> {
    if (this.store === null || this.loadedAccountKey.length === 0) {
      return;
    }
    try {
      await this.store.put(`${KEY_PREFIX}${this.loadedAccountKey}`, JSON.stringify(this.entries));
      await this.store.flush();
    } catch (err) {
      Logger.warn('RecentPlayHistoryStore', `persist failed: ${(err as Error).message}`);
    }
  }

  private static computeAccountKey(): string {
    const auth = AuthStore.getInstance().getCredentials();
    if (auth === null) {
      return '';
    }
    let server: string = auth.remoteServerUrl;
    try {
      server = SubsonicUrlUtil.normalizeServerUrl(auth.remoteServerUrl);
    } catch (_err) {
      server = auth.remoteServerUrl.trim();
    }
    return `${server}::${auth.username}`;
  }

  private static trimEntries(entries: RecentPlayEntry[], nowMs: number): RecentPlayEntry[] {
    const cutoff: number = nowMs - RETENTION_MS;
    const retained: RecentPlayEntry[] = [];
    for (let i: number = 0; i < entries.length; i++) {
      const entry: RecentPlayEntry = entries[i];
      if (entry.playedAt >= cutoff) {
        retained.push(entry);
      }
    }
    return retained.length > MAX_ENTRIES ? retained.slice(0, MAX_ENTRIES) : retained;
  }
}
