/**
 * SonicAPI / Subsonic API 类型定义
 * 参考规范：http://www.subsonic.org/pages/api.jsp
 */

export class SubsonicApiError extends Error {
  code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
    this.name = 'SubsonicApiError';
  }
}

export interface SubsonicError {
  code: number;
  message: string;
}

export interface SubsonicEnvelope {
  status: 'ok' | 'failed';
  version: string;
  type: string;
  serverVersion: string;
  openSubsonic: boolean;
  error?: SubsonicError;
}

export interface Artist {
  id: string;
  name: string;
  albumCount?: number;
  coverArt?: string;
  artistImageUrl?: string;
}

export interface ArtistIndex {
  name: string;
  artist: Artist[];
}

export interface ArtistsContainer {
  index: ArtistIndex[];
  ignoredArticles?: string;
}

export interface ArtistsResponse extends SubsonicEnvelope {
  artists: ArtistsContainer;
}

export interface Album {
  id: string;
  name?: string;
  title?: string;
  artist: string;
  artistId: string;
  coverArt?: string;
  songCount?: number;
  duration?: number;
  year?: number;
  genre?: string;
  created?: string;
  playCount?: number;
  starred?: string;
}

export interface AlbumListContainer {
  album: Album[];
}

export interface AlbumListResponse extends SubsonicEnvelope {
  albumList2: AlbumListContainer;
}

export interface Song {
  id: string;
  parent: string;
  isDir: boolean;
  title: string;
  album: string;
  artist: string;
  track?: number;
  year?: number;
  genre?: string;
  coverArt?: string;
  albumId?: string;
  size: number;
  contentType?: string;
  suffix?: string;
  duration: number;
  bitRate?: number;
  path?: string;
  playCount?: number;
  created?: string;
  starred?: string;
}

export type MusicListKind = 'random' | 'frequent' | 'recent' | 'newest';

export interface RandomSongsContainer {
  song: Song[];
}

export interface RandomSongsResponse extends SubsonicEnvelope {
  randomSongs: RandomSongsContainer;
}

export interface AlbumDetailRouteParam {
  albumId: string;
}

export interface AlbumDetailContainer {
  id: string;
  name: string;
  title?: string;
  artist: string;
  artistId: string;
  coverArt?: string;
  songCount: number;
  duration: number;
  year?: number;
  genre?: string;
  created?: string;
  song: Song[];
}

export interface AlbumDetailResponse extends SubsonicEnvelope {
  album: AlbumDetailContainer;
}

export interface SongDetailResponse extends SubsonicEnvelope {
  song: Song;
}

export interface SearchContainer {
  artist?: Artist[];
  album?: Album[];
  song?: Song[];
}

export interface SearchResponse extends SubsonicEnvelope {
  searchResult3: SearchContainer;
}

/**
 * 歌词行（带时间戳）
 * 用于 LRC 格式歌词解析结果
 */
export interface LyricsLine {
  /** 时间戳（毫秒） */
  timeMs: number;
  /** 歌词文本 */
  text: string;
}

/**
 * 歌词响应
 * Subsonic getLyrics 接口返回结构
 */
export interface LyricsResponse extends SubsonicEnvelope {
  lyrics?: LyricsContainer;
}

export interface LyricsContainer {
  /** 歌手名 */
  artist?: string;
  /** 歌曲名 */
  title?: string;
  /** 原始歌词文本（可能是 LRC 格式） */
  value?: string;
  /** 结构化歌词行 */
  structuredLyrics?: StructuredLyricLine[];
}

export interface StructuredLyricLine {
  /** 开始时间（毫秒） */
  start?: number;
  /** 歌词文本 */
  value?: string;
}
