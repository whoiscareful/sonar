export class CancelToken {
  private cancelled: boolean = false;
  private readonly listeners: Array<() => void> = [];

  get isCancelled(): boolean {
    return this.cancelled;
  }

  cancel(): void {
    if (this.cancelled) {
      return;
    }
    this.cancelled = true;
    for (let i: number = 0; i < this.listeners.length; i++) {
      try {
        this.listeners[i]();
      } catch (_err) {
      }
    }
    this.listeners.length = 0;
  }

  onCancel(listener: () => void): void {
    if (this.cancelled) {
      listener();
      return;
    }
    this.listeners.push(listener);
  }
}
