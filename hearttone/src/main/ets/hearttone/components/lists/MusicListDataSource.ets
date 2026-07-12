import { Song } from '../../api/SubsonicTypes';

/**
 * 音乐列表数据源，用于 LazyForEach 懒加载渲染。
 * 实现 IDataSource 接口，支持大数据量列表性能优化。
 */
export class MusicListDataSource implements IDataSource {
  private songs: Song[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.songs.length;
  }

  getData(index: number): Song {
    return this.songs[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  setSongs(songs: Song[]): void {
    if (this.songs === songs) {
      return;
    }
    this.songs = songs;
    this.notifyReloaded();
  }

  private notifyReloaded(): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }
}
