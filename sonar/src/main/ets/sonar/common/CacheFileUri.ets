import { fileUri } from '@kit.CoreFileKit';

/** 沙箱绝对路径 → ArkUI Image 可加载的 file URI */
export class CacheFileUri {
  static fromAbsolutePath(absolutePath: string): string {
    if (absolutePath.length === 0) {
      return '';
    }
    try {
      return fileUri.getUriFromPath(absolutePath);
    } catch (_err) {
      return `file://${absolutePath}`;
    }
  }
}
