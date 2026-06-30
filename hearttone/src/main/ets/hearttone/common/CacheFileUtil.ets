import { fileIo } from '@kit.CoreFileKit';

/** 沙箱缓存目录共用的文件路径与 IO 工具 */
export class CacheFileUtil {
  static sanitizeId(rawId: string): string {
    return rawId.replace(/[^a-zA-Z0-9_-]/g, '_');
  }

  static fileExists(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      fileIo.statSync(path);
      return true;
    } catch (_err) {
      return false;
    }
  }

  static fileSize(path: string): number {
    try {
      return fileIo.statSync(path).size;
    } catch (_err) {
      return 0;
    }
  }

  static ensureDir(dirPath: string): void {
    if (dirPath.length === 0) {
      return;
    }
    try {
      fileIo.mkdirSync(dirPath, true);
    } catch (_err) {
    }
  }

  static ensureParentDir(filePath: string): void {
    const dirEnd: number = filePath.lastIndexOf('/');
    if (dirEnd <= 0) {
      return;
    }
    CacheFileUtil.ensureDir(filePath.substring(0, dirEnd));
  }

  static removeIfExists(path: string): void {
    try {
      fileIo.unlinkSync(path);
    } catch (_err) {
    }
  }

  static readTextFile(path: string): string | null {
    if (!CacheFileUtil.fileExists(path)) {
      return null;
    }
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const stat = fileIo.statSync(path);
        const buf = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buf);
        return CacheFileUtil.bufferToUtf8(buf);
      } finally {
        try {
          fileIo.closeSync(file);
        } catch (_err) {
        }
      }
    } catch (_err) {
      return null;
    }
  }

  private static closeFileQuietly(file: fileIo.File): void {
    try {
      fileIo.closeSync(file);
    } catch (_err) {
    }
  }

  /** 写入临时文件后 rename，避免半写损坏 */
  static writeTextAtomic(targetPath: string, text: string): void {
    CacheFileUtil.ensureParentDir(targetPath);
    const tempPath: string = `${targetPath}.tmp`;
    CacheFileUtil.removeIfExists(tempPath);
    const bytes: Uint8Array = new Uint8Array(CacheFileUtil.utf8ToBuffer(text));
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(tempPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    } catch (_err) {
      CacheFileUtil.removeIfExists(tempPath);
      return;
    }
    try {
      fileIo.writeSync(file.fd, bytes.buffer);
    } catch (_err) {
      CacheFileUtil.closeFileQuietly(file);
      CacheFileUtil.removeIfExists(tempPath);
      return;
    }
    CacheFileUtil.closeFileQuietly(file);
    CacheFileUtil.removeIfExists(targetPath);
    try {
      fileIo.renameSync(tempPath, targetPath);
    } catch (_err) {
      CacheFileUtil.removeIfExists(tempPath);
    }
  }

  /** 二进制原子写入：.part → rename */
  static writeBufferAtomic(targetPath: string, content: ArrayBuffer): void {
    CacheFileUtil.ensureParentDir(targetPath);
    const tempPath: string = `${targetPath}.part`;
    CacheFileUtil.removeIfExists(tempPath);
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(tempPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    } catch (_err) {
      CacheFileUtil.removeIfExists(tempPath);
      throw new Error('open temp cover file failed');
    }
    try {
      fileIo.writeSync(file.fd, content, { offset: 0, length: content.byteLength });
    } catch (err) {
      CacheFileUtil.closeFileQuietly(file);
      CacheFileUtil.removeIfExists(tempPath);
      throw new Error(`write temp cover file failed: ${(err as Error).message}`);
    }
    CacheFileUtil.closeFileQuietly(file);
    CacheFileUtil.removeIfExists(targetPath);
    try {
      fileIo.renameSync(tempPath, targetPath);
    } catch (err) {
      CacheFileUtil.removeIfExists(tempPath);
      throw new Error(`rename cover file failed: ${(err as Error).message}`);
    }
  }

  static bufferToUtf8(buf: ArrayBuffer): string {
    const bytes: Uint8Array = new Uint8Array(buf);
    let result: string = '';
    for (let i: number = 0; i < bytes.length; i++) {
      result += String.fromCharCode(bytes[i]);
    }
    return result;
  }

  static utf8ToBuffer(text: string): ArrayBuffer {
    const bytes: number[] = [];
    for (let i: number = 0; i < text.length; i++) {
      let code: number = text.charCodeAt(i);
      if (code < 0x80) {
        bytes.push(code);
      } else if (code < 0x800) {
        bytes.push(0xC0 | (code >> 6), 0x80 | (code & 0x3F));
      } else if (code < 0xD800 || code >= 0xE000) {
        bytes.push(0xE0 | (code >> 12), 0x80 | ((code >> 6) & 0x3F), 0x80 | (code & 0x3F));
      } else {
        i++;
        const surrogate: number = text.charCodeAt(i);
        code = 0x10000 + (((code & 0x3FF) << 10) | (surrogate & 0x3FF));
        bytes.push(
          0xF0 | (code >> 18),
          0x80 | ((code >> 12) & 0x3F),
          0x80 | ((code >> 6) & 0x3F),
          0x80 | (code & 0x3F)
        );
      }
    }
    const out: Uint8Array = new Uint8Array(bytes.length);
    for (let j: number = 0; j < bytes.length; j++) {
      out[j] = bytes[j];
    }
    return out.buffer;
  }
}
