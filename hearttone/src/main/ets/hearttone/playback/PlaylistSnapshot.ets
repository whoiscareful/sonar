import { Song } from '../api/SubsonicTypes';

@Observed
export class PlaylistSnapshot {
  readonly items: Song[];
  readonly currentIndex: number;
  readonly revision: number;

  constructor(items: Song[], currentIndex: number, revision: number) {
    this.items = items;
    this.currentIndex = currentIndex;
    this.revision = revision;
  }

  static empty(): PlaylistSnapshot {
    return new PlaylistSnapshot([], -1, 0);
  }
}
