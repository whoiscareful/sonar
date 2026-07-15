import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Logger } from '../common/Logger';

const TOKEN_ALIAS: string = 'hearttone_music_tag_web_bearer';

/**
 * Music Tag Web Bearer Token 的安全存储。
 * 与 Subsonic salt/token 完全隔离，轮换开放 API Token 不会中断播放会话。
 */
export class OpenApiCredentialStore {
  private static bytes(value: string): Uint8Array {
    return util.TextEncoder.create('utf-8').encode(value);
  }

  private static text(value: Uint8Array): string {
    return util.TextDecoder.create('utf-8').decodeToString(value);
  }

  private static aliasQuery(): asset.AssetMap {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, OpenApiCredentialStore.bytes(TOKEN_ALIAS));
    return query;
  }

  static async saveToken(token: string): Promise<void> {
    const normalized: string = OpenApiCredentialStore.normalizeToken(token);
    await OpenApiCredentialStore.clearToken();
    if (normalized.length === 0) {
      return;
    }
    const attributes: asset.AssetMap = OpenApiCredentialStore.aliasQuery();
    attributes.set(asset.Tag.SECRET, OpenApiCredentialStore.bytes(normalized));
    attributes.set(asset.Tag.AUTH_TYPE, asset.AuthType.NONE);
    await asset.add(attributes);
  }

  static normalizeToken(token: string): string {
    let trimmed: string = token.trim();
    const lower: string = trimmed.toLowerCase();
    if (lower.startsWith('jwt ')) {
      trimmed = trimmed.substring(4).trim();
    } else if (lower.startsWith('bearer ')) {
      trimmed = trimmed.substring(7).trim();
    }
    // 兼容从网页、聊天或密码框重复粘贴：移除不可见字符，并选取最后一个
    // Music Tag Web 使用的 32 位字母数字 Token，避免旧内容与新 Token 拼接。
    const compact: string = trimmed.replace(/[\s\u200B-\u200D\u2060\uFEFF]/g, '');
    const candidates: RegExpMatchArray | null = compact.match(/[A-Za-z0-9]{32}/g);
    if (candidates !== null && candidates.length > 0) {
      return candidates[candidates.length - 1];
    }
    return compact;
  }

  static async fingerprint(token: string): Promise<string> {
    const normalized: string = OpenApiCredentialStore.normalizeToken(token);
    if (normalized.length === 0) {
      return '未配置';
    }
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: OpenApiCredentialStore.bytes(normalized) });
    const result = await md.digest();
    let hex: string = '';
    for (let i: number = 0; i < 6 && i < result.data.length; i++) {
      hex += result.data[i].toString(16).padStart(2, '0');
    }
    return `SHA-256 ${hex} · ${normalized.length} 字符`;
  }

  static async getToken(): Promise<string> {
    const query: asset.AssetMap = OpenApiCredentialStore.aliasQuery();
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results: asset.AssetMap[] = await asset.query(query);
      if (results.length === 0) {
        return '';
      }
      const secret: asset.Value | undefined = results[0].get(asset.Tag.SECRET);
      if (secret instanceof Uint8Array) {
        return OpenApiCredentialStore.normalizeToken(OpenApiCredentialStore.text(secret));
      }
    } catch (err) {
      const message: string = (err as Error).message;
      if (!message.includes('24000002')) {
        Logger.warn('OpenApiCredentialStore', `query failed: ${message}`);
      }
    }
    return '';
  }

  static async clearToken(): Promise<void> {
    try {
      await asset.remove(OpenApiCredentialStore.aliasQuery());
    } catch (err) {
      const message: string = (err as Error).message;
      if (!message.includes('24000002')) {
        Logger.warn('OpenApiCredentialStore', `remove failed: ${message}`);
      }
    }
  }
}
