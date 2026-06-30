import { util } from '@kit.ArkTS';
import { RememberedLoginInfo } from '../auth/AuthStore';
import { ConfigCryptoUtil, ConfigEncryptedBlob } from '../crypto/ConfigCryptoUtil';
import {
  DEFAULT_CONFIG_PASSWORD,
  hearttone_CONFIG_VERSION,
  HeartToneConfigEnvelope,
  HeartToneConfigPayload
} from './HeartToneConfigTypes';

export class ConfigCodecError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConfigCodecError';
  }
}

export class HeartToneConfigCodec {
  static resolvePassword(input?: string): string {
    const trimmed = (input ?? '').trim();
    return trimmed.length > 0 ? trimmed : DEFAULT_CONFIG_PASSWORD;
  }

  static async exportConfig(info: RememberedLoginInfo, password?: string): Promise<string> {
    const payload: HeartToneConfigPayload = {
      v: hearttone_CONFIG_VERSION,
      remoteServerUrl: info.remoteServerUrl,
      localServerUrl: info.localServerUrl,
      username: info.username,
      password: info.password
    };
    const plainJson = JSON.stringify(payload);
    const plainBytes = ConfigCryptoUtil.utf8ToBytes(plainJson);
    const resolvedPassword = HeartToneConfigCodec.resolvePassword(password);
    let encrypted: ConfigEncryptedBlob;
    try {
      encrypted = await ConfigCryptoUtil.encrypt(plainBytes, resolvedPassword);
    } catch (err) {
      throw new ConfigCodecError(`加密失败: ${(err as Error).message}`);
    }
    const base64Helper = new util.Base64Helper();
    const envelope: HeartToneConfigEnvelope = {
      v: hearttone_CONFIG_VERSION,
      salt: base64Helper.encodeToStringSync(encrypted.salt),
      iv: base64Helper.encodeToStringSync(encrypted.iv),
      tag: base64Helper.encodeToStringSync(encrypted.tag),
      data: base64Helper.encodeToStringSync(encrypted.cipher)
    };
    const envelopeJson = JSON.stringify(envelope);
    return base64Helper.encodeToStringSync(ConfigCryptoUtil.utf8ToBytes(envelopeJson));
  }

  static async importConfig(base64Input: string, password?: string): Promise<HeartToneConfigPayload> {
    const trimmed = base64Input.trim();
    if (trimmed.length === 0) {
      throw new ConfigCodecError('配置内容为空');
    }
    const base64Helper = new util.Base64Helper();
    let envelopeJson: string;
    try {
      const envelopeBytes = base64Helper.decodeSync(trimmed);
      envelopeJson = ConfigCryptoUtil.bytesToUtf8(envelopeBytes);
    } catch (_err) {
      throw new ConfigCodecError('无效的 Base64 配置');
    }
    let envelope: HeartToneConfigEnvelope;
    try {
      envelope = JSON.parse(envelopeJson) as HeartToneConfigEnvelope;
    } catch (_err) {
      throw new ConfigCodecError('配置格式损坏');
    }
    if (envelope.v !== hearttone_CONFIG_VERSION) {
      throw new ConfigCodecError('不支持的配置版本');
    }
    if (!envelope.salt || !envelope.iv || !envelope.tag || !envelope.data) {
      throw new ConfigCodecError('配置字段不完整');
    }
    let salt: Uint8Array;
    let iv: Uint8Array;
    let tag: Uint8Array;
    let cipher: Uint8Array;
    try {
      salt = base64Helper.decodeSync(envelope.salt);
      iv = base64Helper.decodeSync(envelope.iv);
      tag = base64Helper.decodeSync(envelope.tag);
      cipher = base64Helper.decodeSync(envelope.data);
    } catch (_err) {
      throw new ConfigCodecError('配置字段解码失败');
    }
    const resolvedPassword = HeartToneConfigCodec.resolvePassword(password);
    let plainBytes: Uint8Array;
    try {
      plainBytes = await ConfigCryptoUtil.decrypt(cipher, resolvedPassword, salt, iv, tag);
    } catch (_err) {
      throw new ConfigCodecError('密码错误或配置损坏');
    }
    let payload: HeartToneConfigPayload;
    try {
      payload = JSON.parse(ConfigCryptoUtil.bytesToUtf8(plainBytes)) as HeartToneConfigPayload;
    } catch (_err) {
      throw new ConfigCodecError('解密后配置格式损坏');
    }
    HeartToneConfigCodec.validatePayload(payload);
    return payload;
  }

  private static validatePayload(payload: HeartToneConfigPayload): void {
    if (payload.v !== hearttone_CONFIG_VERSION) {
      throw new ConfigCodecError('不支持的配置版本');
    }
    if (!payload.remoteServerUrl || payload.remoteServerUrl.trim().length === 0) {
      throw new ConfigCodecError('缺少服务器地址');
    }
    if (!payload.username || payload.username.trim().length === 0) {
      throw new ConfigCodecError('缺少用户名');
    }
    if (!payload.password || payload.password.length === 0) {
      throw new ConfigCodecError('缺少密码');
    }
    if (payload.localServerUrl === undefined || payload.localServerUrl === null) {
      payload.localServerUrl = '';
    }
  }
}
