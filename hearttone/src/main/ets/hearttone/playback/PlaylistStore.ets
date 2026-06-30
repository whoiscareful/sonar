import { PlaylistSnapshot } from './PlaylistSnapshot';

const STORAGE_KEY: string = 'playlist';

export class PlaylistStore {
  static init(snapshot: PlaylistSnapshot = PlaylistSnapshot.empty()): void {
    AppStorage.setOrCreate<PlaylistSnapshot>(STORAGE_KEY, snapshot);
  }

  static get(): PlaylistSnapshot {
    const value: PlaylistSnapshot | undefined = AppStorage.get<PlaylistSnapshot>(STORAGE_KEY);
    if (value === undefined) {
      return PlaylistSnapshot.empty();
    }
    return value;
  }

  static publish(snapshot: PlaylistSnapshot): void {
    AppStorage.setOrCreate<PlaylistSnapshot>(STORAGE_KEY, snapshot);
  }
}
