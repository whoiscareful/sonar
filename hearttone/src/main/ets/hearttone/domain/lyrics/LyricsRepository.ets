import { LyricsContainer } from '../../api/SubsonicTypes';
import { Logger } from '../../common/Logger';
import { SubsonicApi } from '../../network/api/SubsonicApi';

/** Bearer Open API 歌词能力的适配边界；具体路径由服务端协议实现后注入。 */
export interface EnhancedLyricsProvider {
  load(songId: string, artist: string, title: string, album: string): Promise<LyricsContainer | null>;
  save(songId: string, artist: string, title: string, album: string, content: string): Promise<void>;
}

export type LyricsSource = 'musicTagWeb' | 'subsonic' | 'none';

/** 歌词读取策略：Music Tag Web 增强接口优先，Subsonic getLyrics 保底。 */
export class LyricsRepository {
  private static provider: EnhancedLyricsProvider | null = null;
  private static lastSource: LyricsSource = 'none';

  static configureEnhancedProvider(provider: EnhancedLyricsProvider | null): void {
    LyricsRepository.provider = provider;
  }

  static getLastSource(): LyricsSource {
    return LyricsRepository.lastSource;
  }

  static async load(songId: string, artist: string, title: string, album: string = ''): Promise<LyricsContainer | null> {
    LyricsRepository.lastSource = 'none';
    if (LyricsRepository.provider !== null) {
      try {
        const enhanced: LyricsContainer | null =
          await LyricsRepository.provider.load(songId, artist, title, album);
        if (enhanced !== null) {
          LyricsRepository.lastSource = 'musicTagWeb';
          return enhanced;
        }
      } catch (err) {
        Logger.warn('LyricsRepository', `enhanced lyrics unavailable: ${(err as Error).message}`);
      }
    }
    const response = await SubsonicApi.getLyrics(artist, title);
    const fallback: LyricsContainer | null = response.lyrics ?? null;
    if (fallback !== null) {
      LyricsRepository.lastSource = 'subsonic';
    }
    return fallback;
  }

  static async save(songId: string, artist: string, title: string, album: string, content: string): Promise<void> {
    if (LyricsRepository.provider === null) {
      throw new Error('Music Tag Web 歌词写入接口尚未配置');
    }
    await LyricsRepository.provider.save(songId, artist, title, album, content);
  }
}
