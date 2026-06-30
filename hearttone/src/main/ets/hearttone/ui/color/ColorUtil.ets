import { image } from '@kit.ImageKit';
import { TaskPoolRunner } from '../../concurrency/TaskPoolRunner';

export class ColorUtil {
  private static normalizeHex(color: string): string {
    let hex: string = color.replace('#', '');
    if (hex.length === 8) {
      hex = hex.substring(2);
    }
    if (hex.length !== 6) {
      return '000000';
    }
    return hex;
  }

  private static byteToHex(value: number): string {
    const clamped: number = Math.max(0, Math.min(255, Math.round(value)));
    const s: string = clamped.toString(16);
    return s.length === 1 ? `0${s}` : s;
  }

  private static rgbToHex(r: number, g: number, b: number): string {
    return `#${ColorUtil.byteToHex(r)}${ColorUtil.byteToHex(g)}${ColorUtil.byteToHex(b)}`;
  }

  /**
   * 计算颜色的亮度（ITU-R BT.709）
   * @param color 十六进制颜色，如 #RRGGBB 或 #AARRGGBB
   * @returns 亮度 0~1
   */
  static calculateLuminance(color: string): number {
    const hex: string = ColorUtil.normalizeHex(color);
    const r: number = parseInt(hex.substring(0, 2), 16) / 255;
    const g: number = parseInt(hex.substring(2, 4), 16) / 255;
    const b: number = parseInt(hex.substring(4, 6), 16) / 255;
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /**
   * @returns true 表示背景偏暗，应使用浅色前景
   */
  static isDarkBackground(color: string, threshold: number = 0.5): boolean {
    return ColorUtil.calculateLuminance(color) < threshold;
  }

  /**
   * 对 PixelMap 底部带状区域求平均色（BGRA_8888）
   */
  static async averageBottomBandFromPixelMap(
    pixelMap: image.PixelMap,
    bandHeightRatio: number = 0.12
  ): Promise<string> {
    const info: image.ImageInfo = await pixelMap.getImageInfo();
    const width: number = info.size.width;
    const height: number = info.size.height;
    if (width <= 0 || height <= 0) {
      return '#808080';
    }
    const bandHeight: number = Math.max(1, Math.floor(height * bandHeightRatio));
    const marginX: number = Math.floor(width * 0.08);
    const regionWidth: number = Math.max(1, width - marginX * 2);
    const regionY: number = Math.max(0, height - bandHeight);
    const bytesPerPixel: number = 4;
    const buffer: ArrayBuffer = new ArrayBuffer(regionWidth * bandHeight * bytesPerPixel);
    const regionSize: image.Size = { width: regionWidth, height: bandHeight };
    const region: image.Region = { x: marginX, y: regionY, size: regionSize };
    const area: image.PositionArea = {
      pixels: buffer,
      offset: 0,
      stride: regionWidth * bytesPerPixel,
      region: region
    };
    await pixelMap.readPixels(area);
    return await TaskPoolRunner.averageBottomBandFromBuffer(
      buffer,
      regionWidth,
      bandHeight,
      bytesPerPixel
    );
  }

  /**
   * 线性混合两色（ratio=0 为 top，ratio=1 为 bottom）
   */
  static blendHex(top: string, bottom: string, ratio: number): string {
    const t: string = ColorUtil.normalizeHex(top);
    const b: string = ColorUtil.normalizeHex(bottom);
    const clamped: number = Math.max(0, Math.min(1, ratio));
    const tr: number = parseInt(t.substring(0, 2), 16);
    const tg: number = parseInt(t.substring(2, 4), 16);
    const tb: number = parseInt(t.substring(4, 6), 16);
    const br: number = parseInt(b.substring(0, 2), 16);
    const bg: number = parseInt(b.substring(2, 4), 16);
    const bb: number = parseInt(b.substring(4, 6), 16);
    const r: number = Math.round(tr + (br - tr) * clamped);
    const g: number = Math.round(tg + (bg - tg) * clamped);
    const bVal: number = Math.round(tb + (bb - tb) * clamped);
    const toHex = (v: number): string => {
      const s: string = v.toString(16);
      return s.length === 1 ? `0${s}` : s;
    };
    return `#${toHex(r)}${toHex(g)}${toHex(bVal)}`;
  }
}
