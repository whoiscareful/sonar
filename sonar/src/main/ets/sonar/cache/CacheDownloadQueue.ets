/** Set 去重 + FIFO 串行下载队列，SongCache / CoverCache 共用 */
export class CacheDownloadQueue {
  private readonly pending: Set<string> = new Set<string>();
  private readonly queue: string[] = [];
  private processing: boolean = false;

  contains(id: string): boolean {
    return this.pending.has(id);
  }

  enqueue(id: string): boolean {
    if (id.length === 0 || this.pending.has(id)) {
      return false;
    }
    this.pending.add(id);
    this.queue.push(id);
    return true;
  }

  remove(id: string): void {
    if (!this.pending.has(id)) {
      return;
    }
    this.pending.delete(id);
    const idx: number = this.queue.indexOf(id);
    if (idx >= 0) {
      this.queue.splice(idx, 1);
    }
  }

  async process(handler: (id: string) => Promise<void>): Promise<void> {
    if (this.processing) {
      return;
    }
    this.processing = true;
    while (this.queue.length > 0) {
      const id: string | undefined = this.queue.shift();
      if (id === undefined || id.length === 0) {
        continue;
      }
      this.pending.delete(id);
      await handler(id);
    }
    this.processing = false;
  }
}
