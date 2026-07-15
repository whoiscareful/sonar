import { LyricsContainer } from '../api/SubsonicTypes';

export interface MusicTagWebStats {
  health?: string;
  albumCount?: string;
  trackCount?: string;
  artistCount?: string;
  songSize?: string;
  songDuration?: string;
  nowPlaying?: string;
}

export interface MusicTagWebHealth {
  healthy: boolean;
  message: string;
}

/**
 * Music Tag Web Bearer API 的协议边界。
 * 只有拿到部署版本的真实 URL、字段与歌词标识方式后才实现，避免猜测接口破坏兼容性。
 */
export interface MusicTagWebOpenApi {
  health(): Promise<MusicTagWebHealth>;
  stats(username?: string, fields?: string): Promise<MusicTagWebStats>;
  loadLyrics(songId: string, artist: string, title: string, album: string): Promise<LyricsContainer | null>;
  saveLyrics(songId: string, artist: string, title: string, album: string, content: string, path?: string): Promise<void>;
  metadataDetailUrl(path: string): string;
  updateProfileAvatar(fileName: string, mimeType: string, data: ArrayBuffer): Promise<string | null>;
  updateProfileCover(fileName: string, mimeType: string, data: ArrayBuffer): Promise<string | null>;
}
