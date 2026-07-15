import { LyricsLine } from '../api/SubsonicTypes';
import { LyricParser } from '../lyrics/LyricParser';
import { Logger } from '../common/Logger';
import { LyricsRepository, LyricsSource } from '../domain/lyrics/LyricsRepository';

/** 歌词加载状态 */
export type LyricLoadState = 'idle' | 'loading' | 'loaded' | 'error' | 'notFound';

@Observed
export class LyricViewModel {
  private static instance: LyricViewModel | null = null;

  /** 当前歌曲 ID */
  currentSongId: string = '';
  /** 当前歌曲名 */
  currentTitle: string = '';
  /** 当前歌手名 */
  currentArtist: string = '';
  /** 当前专辑名 */
  currentAlbum: string = '';
  /** 解析后的歌词行 */
  lines: LyricsLine[] = [];
  /** 当前行索引 */
  currentLineIndex: number = -1;
  /** 加载状态 */
  loadState: LyricLoadState = 'idle';
  /** 错误信息 */
  errorMessage: string = '';
  /** 当前歌词实际来源。 */
  source: LyricsSource = 'none';
  /** 歌词时间偏移量（毫秒），正值表示歌词提前，负值表示歌词延后 */
  timeOffsetMs: number = 0;
  /** 每次调整的偏移步长（毫秒） */
  static readonly OFFSET_STEP_MS: number = 500;
  /** 最大偏移量（毫秒） */
  static readonly MAX_OFFSET_MS: number = 10000;

  private constructor() {
  }

  static getInstance(): LyricViewModel {
    if (LyricViewModel.instance === null) {
      LyricViewModel.instance = new LyricViewModel();
    }
    return LyricViewModel.instance;
  }

  /**
   * 为指定歌曲加载歌词
   * @param songId 歌曲 ID
   * @param artist 歌手名
   * @param title 歌曲名
   */
  async loadLyrics(songId: string, artist: string, title: string, album: string = ''): Promise<void> {
    // 如果是同一首歌，不重复加载
    if (this.currentSongId === songId && this.loadState !== 'error') {
      return;
    }

    this.currentSongId = songId;
    this.currentArtist = artist;
    this.currentTitle = title;
    this.currentAlbum = album;
    this.lines = [];
    this.currentLineIndex = -1;
    this.loadState = 'loading';
    this.errorMessage = '';
    this.source = 'none';
    this.timeOffsetMs = 0; // 重置偏移量

    try {
      Logger.debug('LyricViewModel', `Loading lyrics for: ${artist} - ${title}`);
      const lyrics = await LyricsRepository.load(songId, artist, title, album);
      this.source = LyricsRepository.getLastSource();

      if (lyrics === null) {
        this.loadState = 'notFound';
        Logger.debug('LyricViewModel', 'No lyrics found');
        return;
      }

      const parsedLines: LyricsLine[] = LyricParser.parseFromContainer(lyrics);
      if (parsedLines.length === 0) {
        this.loadState = 'notFound';
        Logger.debug('LyricViewModel', 'Lyrics container empty');
        return;
      }

      this.lines = parsedLines;
      this.loadState = 'loaded';
      Logger.debug('LyricViewModel', `Loaded ${parsedLines.length} lyric lines`);
    } catch (err) {
      const error: Error = err as Error;
      Logger.warn('LyricViewModel', `Failed to load lyrics: ${error.message}`);
      this.loadState = 'error';
      this.errorMessage = error.message;
      this.source = 'none';
    }
  }

  /**
   * 根据播放位置更新当前行索引
   * @param positionMs 当前播放位置（毫秒）
   */
  updatePosition(positionMs: number): void {
    if (this.lines.length === 0) {
      this.currentLineIndex = -1;
      return;
    }

    // 应用偏移量：如果偏移量为正，歌词需要更早显示（减去偏移）
    const adjustedPositionMs = positionMs - this.timeOffsetMs;
    const newIndex: number = LyricParser.findCurrentLineIndex(this.lines, adjustedPositionMs);
    if (newIndex !== this.currentLineIndex) {
      this.currentLineIndex = newIndex;
    }
  }

  /**
   * 增加歌词偏移量（歌词显示延后）
   */
  increaseOffset(): number {
    if (this.timeOffsetMs < LyricViewModel.MAX_OFFSET_MS) {
      this.timeOffsetMs += LyricViewModel.OFFSET_STEP_MS;
    }
    return this.timeOffsetMs;
  }

  /**
   * 减少歌词偏移量（歌词显示提前）
   */
  decreaseOffset(): number {
    if (this.timeOffsetMs > -LyricViewModel.MAX_OFFSET_MS) {
      this.timeOffsetMs -= LyricViewModel.OFFSET_STEP_MS;
    }
    return this.timeOffsetMs;
  }

  /**
   * 重置偏移量
   */
  resetOffset(): void {
    this.timeOffsetMs = 0;
  }

  /**
   * 获取偏移量显示文本
   */
  getOffsetText(): string {
    if (this.timeOffsetMs === 0) {
      return '0s';
    }
    const seconds = this.timeOffsetMs / 1000;
    const sign = seconds > 0 ? '+' : '';
    return `${sign}${seconds.toFixed(1)}s`;
  }

  /**
   * 获取指定行的时间（毫秒）
   * @param lineIndex 行索引
   */
  getLineTimeMs(lineIndex: number): number {
    if (lineIndex < 0 || lineIndex >= this.lines.length) {
      return 0;
    }
    return this.lines[lineIndex].timeMs;
  }

  /**
   * 重置状态（切换歌曲时调用）
   */
  reset(): void {
    this.currentSongId = '';
    this.currentTitle = '';
    this.currentArtist = '';
    this.currentAlbum = '';
    this.lines = [];
    this.currentLineIndex = -1;
    this.loadState = 'idle';
    this.errorMessage = '';
    this.source = 'none';
    this.timeOffsetMs = 0;
  }

  /**
   * 是否有可用歌词
   */
  hasLyrics(): boolean {
    return this.lines.length > 0;
  }

  /**
   * 获取当前行歌词文本
   */
  getCurrentLineText(): string {
    if (this.currentLineIndex < 0 || this.currentLineIndex >= this.lines.length) {
      return '';
    }
    return this.lines[this.currentLineIndex].text;
  }

  async saveCurrentLyrics(): Promise<void> {
    if (this.currentSongId.length === 0 || this.lines.length === 0) {
      throw new Error('当前没有可保存的歌词');
    }
    await LyricsRepository.save(
      this.currentSongId,
      this.currentArtist,
      this.currentTitle,
      this.currentAlbum,
      this.toLrcText()
    );
  }

  sourceLabel(): string {
    if (this.source === 'musicTagWeb') {
      return 'Music Tag Web';
    }
    if (this.source === 'subsonic') {
      return 'Subsonic';
    }
    return '暂无来源';
  }

  private toLrcText(): string {
    const rows: string[] = [];
    for (let i: number = 0; i < this.lines.length; i++) {
      const line: LyricsLine = this.lines[i];
      const totalCentiseconds: number = Math.max(0, Math.floor(line.timeMs / 10));
      const minutes: number = Math.floor(totalCentiseconds / 6000);
      const seconds: number = Math.floor((totalCentiseconds % 6000) / 100);
      const centiseconds: number = totalCentiseconds % 100;
      const mm: string = minutes < 10 ? `0${minutes}` : `${minutes}`;
      const ss: string = seconds < 10 ? `0${seconds}` : `${seconds}`;
      const cc: string = centiseconds < 10 ? `0${centiseconds}` : `${centiseconds}`;
      rows.push(`[${mm}:${ss}.${cc}]${line.text}`);
    }
    return rows.join('\n');
  }
}
