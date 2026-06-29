import { CoverCache } from '../playback/CoverCache';

/** 列表/曲库封面 URL 解析统一入口（不含入队，入队由 UI onVisibleAreaChange 触发） */
export class CoverDisplayResolver {
  static resolve(coverArt: string | undefined, displaySize: number): string | undefined {
    if (coverArt === undefined || coverArt.length === 0) {
      return undefined;
    }
    return CoverCache.resolveDisplayUrl(coverArt, displaySize);
  }

  static enqueueWhenVisible(coverArt: string | undefined): void {
    if (coverArt === undefined || coverArt.length === 0) {
      return;
    }
    CoverCache.maybeEnqueue(coverArt);
  }
}
