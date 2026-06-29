import { PlaybackPhase, PlaybackSnapshot } from './PlaybackSnapshot';

const STORAGE_KEY: string = 'playback';
const TRACK_ID_KEY: string = 'playbackTrackId';
const PHASE_KEY: string = 'playbackPhase';
const SESSION_READY_KEY: string = 'playbackSessionReady';

export class PlaybackStore {
  static init(snapshot: PlaybackSnapshot = PlaybackSnapshot.idle()): void {
    AppStorage.setOrCreate<PlaybackSnapshot>(STORAGE_KEY, snapshot);
    AppStorage.setOrCreate<string>(TRACK_ID_KEY, PlaybackStore.resolveTrackId(snapshot));
    AppStorage.setOrCreate<PlaybackPhase>(PHASE_KEY, snapshot.phase);
    AppStorage.setOrCreate<boolean>(SESSION_READY_KEY, false);
  }

  static setSessionReady(ready: boolean): void {
    AppStorage.setOrCreate<boolean>(SESSION_READY_KEY, ready);
  }

  static isSessionReady(): boolean {
    const ready: boolean | undefined = AppStorage.get<boolean>(SESSION_READY_KEY);
    return ready === true;
  }

  static get(): PlaybackSnapshot {
    const value: PlaybackSnapshot | undefined = AppStorage.get<PlaybackSnapshot>(STORAGE_KEY);
    if (value === undefined) {
      return PlaybackSnapshot.idle();
    }
    return value;
  }

  static publish(snapshot: PlaybackSnapshot): void {
    AppStorage.setOrCreate<PlaybackSnapshot>(STORAGE_KEY, snapshot);
    const trackId: string = PlaybackStore.resolveTrackId(snapshot);
    const prevTrackId: string = AppStorage.get<string>(TRACK_ID_KEY) ?? '';
    if (trackId !== prevTrackId) {
      AppStorage.setOrCreate<string>(TRACK_ID_KEY, trackId);
    }
    const prevPhase: PlaybackPhase = AppStorage.get<PlaybackPhase>(PHASE_KEY) ?? 'idle';
    if (snapshot.phase !== prevPhase) {
      AppStorage.setOrCreate<PlaybackPhase>(PHASE_KEY, snapshot.phase);
    }
  }

  private static resolveTrackId(snapshot: PlaybackSnapshot): string {
    if (snapshot.track === null) {
      return '';
    }
    return snapshot.track.id;
  }
}
