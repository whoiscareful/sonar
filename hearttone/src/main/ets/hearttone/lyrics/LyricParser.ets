import { LyricsLine, LyricsContainer, StructuredLyricLine } from '../api/SubsonicTypes';

/**
 * LRC 歌词解析器
 * 支持标准 LRC 格式：[mm:ss.xx]歌词文本
 */
export class LyricParser {
  /** 歌词行之间的最大间隔（毫秒），超过此值会添加填充行 */
  private static readonly MAX_GAP_MS: number = 8000;
  /** 填充行文本 */
  private static readonly FILLER_TEXT: string = '♪';

  /**
   * 解析 LRC 格式歌词文本
   * @param lrcText LRC 格式歌词
   * @returns 解析后的歌词行数组，按时间排序
   */
  static parseLrc(lrcText: string): LyricsLine[] {
    if (lrcText === undefined || lrcText === null || lrcText.trim().length === 0) {
      return [];
    }

    const lines: LyricsLine[] = [];
    const lineTexts: string[] = lrcText.split('\n');

    for (let i: number = 0; i < lineTexts.length; i++) {
      const line: string = lineTexts[i].trim();
      if (line.length === 0) {
        continue;
      }

      // 解析时间标签 [mm:ss.xx] 或 [mm:ss:xx]
      const timeMatch: RegExpMatchArray | null = line.match(/^\[(\d+):(\d+)(?:[.:](\d+))?\]/);
      if (timeMatch === null) {
        continue;
      }

      const minutes: number = parseInt(timeMatch[1], 10);
      const seconds: number = parseInt(timeMatch[2], 10);
      const milliseconds: number = timeMatch[3] !== undefined ? parseInt(timeMatch[3], 10) : 0;

      // 计算总毫秒数
      let timeMs: number = minutes * 60 * 1000 + seconds * 1000;
      // 处理毫秒部分（可能是2位或3位）
      if (milliseconds > 0) {
        if (milliseconds < 100) {
          timeMs += milliseconds * 10; // 2位小数
        } else {
          timeMs += milliseconds; // 3位小数
        }
      }

      // 提取歌词文本
      const text: string = line.substring(timeMatch[0].length).trim();

      // 跳过空文本的歌词行（只有时间标签没有内容）
      if (text.length === 0) {
        continue;
      }

      lines.push({
        timeMs: timeMs,
        text: text
      });
    }

    // 按时间排序
    lines.sort((a: LyricsLine, b: LyricsLine): number => a.timeMs - b.timeMs);

    return lines;
  }

  /**
   * 从 Subsonic LyricsContainer 解析歌词
   * 优先使用结构化歌词，否则解析 LRC 文本
   * @param container Subsonic 歌词容器
   * @returns 解析后的歌词行数组
   */
  static parseFromContainer(container: LyricsContainer | undefined): LyricsLine[] {
    if (container === undefined || container === null) {
      return [];
    }

    let lines: LyricsLine[] = [];

    // 优先使用结构化歌词
    if (container.structuredLyrics !== undefined && container.structuredLyrics.length > 0) {
      for (let i: number = 0; i < container.structuredLyrics.length; i++) {
        const structuredLine: StructuredLyricLine = container.structuredLyrics[i];
        const text: string = (structuredLine.value ?? '').trim();
        // 跳过空文本
        if (text.length === 0) {
          continue;
        }
        lines.push({
          timeMs: structuredLine.start ?? 0,
          text: text
        });
      }
      lines.sort((a: LyricsLine, b: LyricsLine): number => a.timeMs - b.timeMs);
    } else if (container.value !== undefined && container.value.length > 0) {
      // 否则解析 LRC 文本
      lines = LyricParser.parseLrc(container.value);
    }

    // 填充时间间隔
    return LyricParser.fillGaps(lines);
  }

  /**
   * 填充歌词行之间的时间间隔
   * 当两行之间的时间差超过阈值时，添加填充行
   * @param lines 原始歌词行
   * @returns 填充后的歌词行
   */
  private static fillGaps(lines: LyricsLine[]): LyricsLine[] {
    if (lines.length < 2) {
      return lines;
    }

    const result: LyricsLine[] = [];

    for (let i: number = 0; i < lines.length; i++) {
      result.push(lines[i]);

      // 检查与下一行的间隔
      if (i < lines.length - 1) {
        const currentTime: number = lines[i].timeMs;
        const nextTime: number = lines[i + 1].timeMs;
        const gap: number = nextTime - currentTime;

        // 如果间隔超过阈值，添加填充行
        if (gap > LyricParser.MAX_GAP_MS) {
          // 在间隔中间位置添加填充行
          const fillerTime: number = currentTime + Math.floor(gap / 2);
          result.push({
            timeMs: fillerTime,
            text: LyricParser.FILLER_TEXT
          });
        }
      }
    }

    // 重新排序（确保填充行在正确位置）
    result.sort((a: LyricsLine, b: LyricsLine): number => a.timeMs - b.timeMs);

    return result;
  }

  /**
   * 根据当前播放时间查找当前歌词行索引
   * @param lines 歌词行数组
   * @param positionMs 当前播放位置（毫秒）
   * @returns 当前行索引，如果没有歌词返回 -1
   */
  static findCurrentLineIndex(lines: LyricsLine[], positionMs: number): number {
    if (lines.length === 0) {
      return -1;
    }

    // 找到最后一个时间小于等于当前位置的行
    let index: number = -1;
    for (let i: number = 0; i < lines.length; i++) {
      if (lines[i].timeMs <= positionMs) {
        index = i;
      } else {
        break;
      }
    }

    return index;
  }
}
