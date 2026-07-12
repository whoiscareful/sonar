import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';
import { Logger } from './Logger';

const TAG: string = 'CryptoUtil';

/**
 * AES-128-ECB + PKCS5 对称加密工具。
 * 用于本地敏感数据（如记住的密码）加密存储，防止 preferences 文件被直接读取明文。
 * 密钥由应用固定种子派生，主要防御离线文件提取场景。
 */
export class CryptoUtil {
  private static cipher: cryptoFramework.Cipher | null = null;
  private static symKey: cryptoFramework.SymKey | null = null;
  private static initialized: boolean = false;

  private static readonly KEY_SEED: Uint8Array = new Uint8Array([
    0x48, 0x65, 0x61, 0x72, 0x74, 0x54, 0x6F, 0x6E,
    0x65, 0x5F, 0x53, 0x65, 0x63, 0x72, 0x65, 0x74
  ]);

  private static ensureInitialized(): void {
    if (CryptoUtil.initialized) {
      return;
    }
    try {
      const keyGenerator: cryptoFramework.SymKeyGenerator =
        cryptoFramework.createSymKeyGenerator('AES128');
      const keyData: cryptoFramework.DataBlob = { data: CryptoUtil.KEY_SEED };
      CryptoUtil.symKey = keyGenerator.generateSymKeySync(keyData);
      CryptoUtil.cipher = cryptoFramework.createCipher('AES128|ECB|PKCS5');
      CryptoUtil.initialized = true;
    } catch (err) {
      Logger.error(TAG, `init failed: ${(err as Error).message}`);
    }
  }

  /**
   * 加密明文字符串，返回 base64 编码的密文。
   * 加密失败时返回原文（降级策略，不阻断业务流程）。
   */
  static encrypt(plaintext: string): string {
    if (plaintext.length === 0) {
      return '';
    }
    CryptoUtil.ensureInitialized();
    if (CryptoUtil.cipher === null || CryptoUtil.symKey === null) {
      Logger.warn(TAG, 'encrypt skipped: cipher not initialized');
      return plaintext;
    }
    try {
      CryptoUtil.cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, CryptoUtil.symKey, null);
      const plainBytes: Uint8Array = new TextEncoder().encodeIntoUint8Array(plaintext);
      const result: cryptoFramework.DataBlob =
        CryptoUtil.cipher.doFinalSync({ data: plainBytes });
      return buffer.from(result.data).toString('base64');
    } catch (err) {
      Logger.error(TAG, `encrypt failed: ${(err as Error).message}`);
      return plaintext;
    }
  }

  /**
   * 解密 base64 编码的密文，返回明文字符串。
   * 解密失败时返回原文（兼容旧版明文存储的降级策略）。
   */
  static decrypt(ciphertext: string): string {
    if (ciphertext.length === 0) {
      return '';
    }
    CryptoUtil.ensureInitialized();
    if (CryptoUtil.cipher === null || CryptoUtil.symKey === null) {
      Logger.warn(TAG, 'decrypt skipped: cipher not initialized');
      return ciphertext;
    }
    try {
      CryptoUtil.cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, CryptoUtil.symKey, null);
      const encryptedBytes: Uint8Array =
        new Uint8Array(buffer.from(ciphertext, 'base64').buffer);
      const result: cryptoFramework.DataBlob =
        CryptoUtil.cipher.doFinalSync({ data: encryptedBytes });
      return new TextDecoder().decodeToString(result.data);
    } catch (err) {
      // 兼容旧版明文存储：解密失败时返回原文
      Logger.warn(TAG, `decrypt failed, returning raw value: ${(err as Error).message}`);
      return ciphertext;
    }
  }
}
