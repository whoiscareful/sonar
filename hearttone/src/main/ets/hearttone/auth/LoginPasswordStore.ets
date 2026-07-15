import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { Logger } from '../common/Logger';

const PASSWORD_ALIAS: string = 'hearttone_server_login_password';

/** 服务器登录密码仅保存在系统 Asset Store，不写入 Preferences。 */
export class LoginPasswordStore {
  private static bytes(value: string): Uint8Array {
    return util.TextEncoder.create('utf-8').encode(value);
  }

  private static text(value: Uint8Array): string {
    return util.TextDecoder.create('utf-8').decodeToString(value);
  }

  private static aliasQuery(): asset.AssetMap {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, LoginPasswordStore.bytes(PASSWORD_ALIAS));
    return query;
  }

  static async save(password: string): Promise<void> {
    await LoginPasswordStore.clear();
    if (password.length === 0) {
      return;
    }
    const attributes: asset.AssetMap = LoginPasswordStore.aliasQuery();
    attributes.set(asset.Tag.SECRET, LoginPasswordStore.bytes(password));
    attributes.set(asset.Tag.AUTH_TYPE, asset.AuthType.NONE);
    await asset.add(attributes);
  }

  static async get(): Promise<string> {
    const query: asset.AssetMap = LoginPasswordStore.aliasQuery();
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results: asset.AssetMap[] = await asset.query(query);
      if (results.length === 0) {
        return '';
      }
      const secret: asset.Value | undefined = results[0].get(asset.Tag.SECRET);
      if (secret instanceof Uint8Array) {
        return LoginPasswordStore.text(secret);
      }
    } catch (err) {
      const message: string = (err as Error).message;
      if (!message.includes('24000002')) {
        Logger.warn('LoginPasswordStore', `query failed: ${message}`);
      }
    }
    return '';
  }

  static async clear(): Promise<void> {
    try {
      await asset.remove(LoginPasswordStore.aliasQuery());
    } catch (err) {
      const message: string = (err as Error).message;
      if (!message.includes('24000002')) {
        Logger.warn('LoginPasswordStore', `remove failed: ${message}`);
      }
    }
  }
}
