/**
 * 简单的随机工具：生成 Subsonic 协议要求的客户端 salt
 */
export class RandomUtil {
  static generateSalt(length: number = 6): string {
    const chars: string = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let s: string = '';
    for (let i = 0; i < length; i++) {
      s += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return s;
  }
}
