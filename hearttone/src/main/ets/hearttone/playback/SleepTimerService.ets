import { PlaybackService } from './PlaybackService';
import { PlaylistSnapshot } from './PlaylistSnapshot';

/** 独立于播放页生命周期的定时关闭服务。 */
export class SleepTimerService {
  private static timerId: number | null = null;
  private static endAtMs: number = 0;
  private static modeLabel: string = '';
  private static targetTrackId: string = '';

  static set(minutes: number): void {
    SleepTimerService.cancelTimerOnly();
    if (minutes <= 0) {
      SleepTimerService.endAtMs = 0;
      SleepTimerService.modeLabel = '';
      SleepTimerService.targetTrackId = '';
      SleepTimerService.publish();
      return;
    }
    SleepTimerService.schedule(minutes * 60 * 1000, `${minutes} 分钟后`, '');
  }

  static setUntilCurrentTrackEnds(): boolean {
    const snapshot = PlaybackService.getSnapshot();
    if (snapshot.track === null || snapshot.track.durationMs <= 0) {
      return false;
    }
    const remainingMs: number = snapshot.track.durationMs - PlaybackService.getAuthoritativePositionMs();
    if (remainingMs <= 0) {
      return false;
    }
    SleepTimerService.schedule(remainingMs + 700, '播完当前歌曲', snapshot.track.id);
    return true;
  }

  static setUntilCurrentAlbumEnds(): boolean {
    const playlist: PlaylistSnapshot = PlaybackService.getPlaylistSnapshot();
    const currentIndex: number = playlist.currentIndex;
    if (currentIndex < 0 || currentIndex >= playlist.items.length) {
      return SleepTimerService.setUntilCurrentTrackEnds();
    }
    const currentSong = playlist.items[currentIndex];
    const albumName: string = currentSong.album;
    let remainingMs: number = Math.max(0, (currentSong.duration * 1000) - PlaybackService.getAuthoritativePositionMs());
    for (let i: number = currentIndex + 1; i < playlist.items.length; i++) {
      const song = playlist.items[i];
      if (song.album !== albumName) {
        break;
      }
      remainingMs += Math.max(0, song.duration * 1000);
    }
    if (remainingMs <= 0) {
      return SleepTimerService.setUntilCurrentTrackEnds();
    }
    SleepTimerService.schedule(remainingMs + 900, '播完当前专辑', '');
    return true;
  }

  private static schedule(delayMs: number, label: string, targetTrackId: string): void {
    SleepTimerService.cancelTimerOnly();
    SleepTimerService.endAtMs = Date.now() + delayMs;
    SleepTimerService.modeLabel = label;
    SleepTimerService.targetTrackId = targetTrackId;
    SleepTimerService.timerId = setTimeout(() => {
      const shouldPause: boolean = SleepTimerService.shouldPauseOnTimeout();
      SleepTimerService.timerId = null;
      SleepTimerService.endAtMs = 0;
      SleepTimerService.modeLabel = '';
      SleepTimerService.targetTrackId = '';
      SleepTimerService.publish();
      if (shouldPause) {
        void PlaybackService.toggle();
      }
    }, delayMs) as number;
    SleepTimerService.publish();
  }

  static cancel(): void {
    SleepTimerService.cancelTimerOnly();
    SleepTimerService.endAtMs = 0;
    SleepTimerService.modeLabel = '';
    SleepTimerService.targetTrackId = '';
    SleepTimerService.publish();
  }

  static isActive(): boolean {
    return SleepTimerService.endAtMs > Date.now();
  }

  static remainingMinutes(): number {
    if (!SleepTimerService.isActive()) {
      return 0;
    }
    return Math.max(1, Math.ceil((SleepTimerService.endAtMs - Date.now()) / 60000));
  }

  static label(): string {
    if (!SleepTimerService.isActive()) {
      return '未开启';
    }
    const prefix: string = SleepTimerService.modeLabel.length > 0 ? SleepTimerService.modeLabel : '定时关闭';
    return `${prefix} · 剩余约 ${SleepTimerService.remainingMinutes()} 分钟`;
  }

  private static shouldPauseOnTimeout(): boolean {
    const snapshot = PlaybackService.getSnapshot();
    if (!snapshot.isPlaying()) {
      return false;
    }
    if (SleepTimerService.targetTrackId.length === 0) {
      return true;
    }
    return snapshot.track !== null && snapshot.track.id === SleepTimerService.targetTrackId;
  }

  private static cancelTimerOnly(): void {
    if (SleepTimerService.timerId !== null) {
      clearTimeout(SleepTimerService.timerId);
      SleepTimerService.timerId = null;
    }
  }

  private static publish(): void {
    const revision: number = AppStorage.get<number>('sleepTimerRevision') ?? 0;
    AppStorage.setOrCreate<number>('sleepTimerRevision', revision + 1);
  }
}
