const PERSIST_DEBOUNCE_MS: number = 2000;

/** 磁盘索引 debounce 持久化，SongCache / CoverCache 共用 */
export class CachePersistScheduler {
  private persistTimerId: number = -1;
  private persistDirty: boolean = false;
  private persistInFlight: Promise<void> | null = null;

  schedulePersist(writeIndex: () => Promise<void>): void {
    this.persistDirty = true;
    if (this.persistTimerId >= 0) {
      return;
    }
    this.persistTimerId = setTimeout((): void => {
      this.persistTimerId = -1;
      if (!this.persistDirty) {
        return;
      }
      this.persistDirty = false;
      void this.flushPersist(writeIndex);
    }, PERSIST_DEBOUNCE_MS);
  }

  async flushPersist(writeIndex: () => Promise<void>): Promise<void> {
    while (true) {
      if (this.persistInFlight !== null) {
        await this.persistInFlight;
        continue;
      }
      this.persistDirty = false;
      const task: Promise<void> = writeIndex();
      this.persistInFlight = task;
      try {
        await task;
      } finally {
        this.persistInFlight = null;
      }
      if (!this.persistDirty) {
        break;
      }
    }
  }
}
