import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';

const PBKDF2_ITERATIONS: number = 10000;
const KEY_SIZE_BYTES: number = 16;
const SALT_SIZE: number = 16;
const IV_SIZE: number = 12;

export interface ConfigEncryptedBlob {
  salt: Uint8Array;
  iv: Uint8Array;
  tag: Uint8Array;
  cipher: Uint8Array;
}

function stringToUtf8Bytes(str: string): Uint8Array {
  return new Uint8Array(buffer.from(str, 'utf-8').buffer);
}

function generateRandomBytes(len: number): Uint8Array {
  try {
    const rand = cryptoFramework.createRandom();
    try {
      const blob = rand.generateRandomSync(len);
      return blob.data;
    } catch (err) {
      throw new Error(`generateRandomSync failed: ${(err as Error).message}`);
    }
  } catch (err) {
    throw new Error(`createRandom failed: ${(err as Error).message}`);
  }
}

function buildGcmParams(iv: Uint8Array, authTag: Uint8Array): cryptoFramework.GcmParamsSpec {
  const aadBlob: cryptoFramework.DataBlob = { data: new Uint8Array(0) };
  const ivBlob: cryptoFramework.DataBlob = { data: iv };
  const tagBlob: cryptoFramework.DataBlob = { data: authTag };
  return {
    iv: ivBlob,
    aad: aadBlob,
    authTag: tagBlob,
    algName: 'GcmParamsSpec'
  };
}

async function deriveAes128Key(password: string, salt: Uint8Array): Promise<cryptoFramework.SymKey> {
  const spec: cryptoFramework.PBKDF2Spec = {
    algName: 'PBKDF2',
    password: password,
    salt: salt,
    iterations: PBKDF2_ITERATIONS,
    keySize: KEY_SIZE_BYTES
  };
  try {
    const kdf = cryptoFramework.createKdf('PBKDF2|SHA256');
    let secret: cryptoFramework.DataBlob;
    try {
      secret = await kdf.generateSecret(spec);
    } catch (err) {
      throw new Error(`generateSecret failed: ${(err as Error).message}`);
    }
    try {
      const aesGenerator = cryptoFramework.createSymKeyGenerator('AES128');
      const symKeyBlob: cryptoFramework.DataBlob = { data: secret.data };
      try {
        return await aesGenerator.convertKey(symKeyBlob);
      } catch (err) {
        throw new Error(`convertKey failed: ${(err as Error).message}`);
      }
    } catch (err) {
      throw new Error(`createSymKeyGenerator failed: ${(err as Error).message}`);
    }
  } catch (err) {
    throw new Error(`createKdf failed: ${(err as Error).message}`);
  }
}

export class ConfigCryptoUtil {
  static async encrypt(plain: Uint8Array, password: string): Promise<ConfigEncryptedBlob> {
    const salt = generateRandomBytes(SALT_SIZE);
    const iv = generateRandomBytes(IV_SIZE);
    const symKey = await deriveAes128Key(password, salt);
    const zeroTag = new Uint8Array(16);
    const gcmParams = buildGcmParams(iv, zeroTag);
    try {
      const cipher = cryptoFramework.createCipher('AES128|GCM|PKCS7');
      try {
        await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, gcmParams);
      } catch (err) {
        throw new Error(`cipher init failed: ${(err as Error).message}`);
      }
      const plainBlob: cryptoFramework.DataBlob = { data: plain };
      let encryptUpdate: cryptoFramework.DataBlob | null;
      try {
        encryptUpdate = await cipher.update(plainBlob);
      } catch (err) {
        throw new Error(`cipher update failed: ${(err as Error).message}`);
      }
      let authTagBlob: cryptoFramework.DataBlob | null;
      try {
        authTagBlob = await cipher.doFinal(null);
      } catch (err) {
        throw new Error(`cipher doFinal failed: ${(err as Error).message}`);
      }
      if (authTagBlob === null || authTagBlob.data === undefined) {
        throw new Error('AES-GCM encrypt: missing auth tag');
      }
      if (encryptUpdate === null || encryptUpdate.data === undefined) {
        throw new Error('AES-GCM encrypt: missing ciphertext');
      }
      return {
        salt,
        iv,
        tag: authTagBlob.data,
        cipher: encryptUpdate.data
      };
    } catch (err) {
      throw new Error(`createCipher failed: ${(err as Error).message}`);
    }
  }

  static async decrypt(
    cipher: Uint8Array,
    password: string,
    salt: Uint8Array,
    iv: Uint8Array,
    tag: Uint8Array
  ): Promise<Uint8Array> {
    const symKey = await deriveAes128Key(password, salt);
    const gcmParams = buildGcmParams(iv, tag);
    try {
      const decoder = cryptoFramework.createCipher('AES128|GCM|PKCS7');
      try {
        await decoder.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, gcmParams);
      } catch (err) {
        throw new Error(`decoder init failed: ${(err as Error).message}`);
      }
      const cipherBlob: cryptoFramework.DataBlob = { data: cipher };
      let decryptUpdate: cryptoFramework.DataBlob | null;
      try {
        decryptUpdate = await decoder.update(cipherBlob);
      } catch (err) {
        throw new Error(`decoder update failed: ${(err as Error).message}`);
      }
      try {
        await decoder.doFinal(null);
      } catch (err) {
        throw new Error(`decoder doFinal failed: ${(err as Error).message}`);
      }
      if (decryptUpdate === null || decryptUpdate.data === undefined) {
        throw new Error('AES-GCM decrypt failed');
      }
      return decryptUpdate.data;
    } catch (err) {
      throw new Error(`createCipher failed: ${(err as Error).message}`);
    }
  }

  static utf8ToBytes(str: string): Uint8Array {
    return stringToUtf8Bytes(str);
  }

  static bytesToUtf8(bytes: Uint8Array): string {
    try {
      return buffer.from(bytes).toString('utf-8');
    } catch (err) {
      throw new Error(`bytesToUtf8 failed: ${(err as Error).message}`);
    }
  }
}
