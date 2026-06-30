import { cryptoFramework } from '@kit.CryptoArchitectureKit';

function stringToUtf8Bytes(str: string): Uint8Array {
  const bytes: number[] = [];
  for (let i = 0; i < str.length; i++) {
    const c: number = str.charCodeAt(i);
    if (c < 0x80) {
      bytes.push(c);
    } else if (c < 0x800) {
      bytes.push(0xc0 | (c >> 6));
      bytes.push(0x80 | (c & 0x3f));
    } else {
      bytes.push(0xe0 | (c >> 12));
      bytes.push(0x80 | ((c >> 6) & 0x3f));
      bytes.push(0x80 | (c & 0x3f));
    }
  }
  return new Uint8Array(bytes);
}

function bytesToHex(bytes: Uint8Array): string {
  let s: string = '';
  for (let i = 0; i < bytes.length; i++) {
    const b: number = bytes[i];
    s += b.toString(16).padStart(2, '0');
  }
  return s;
}

export class Md5Util {
  /**
   * 计算字符串的 MD5 十六进制摘要。
   * Subsonic 协议使用 md5(password + salt) 作为 token。
   */
  static async md5Hex(input: string): Promise<string> {
    try {
      const md = cryptoFramework.createMd('MD5');
      await md.update({ data: stringToUtf8Bytes(input) });
      const result = await md.digest();
      return bytesToHex(result.data);
    } catch (err) {
      throw new Error(`MD5 failed: ${(err as Error).message}`);
    }
  }
}
