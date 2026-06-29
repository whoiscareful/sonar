import { SubsonicApiError, SubsonicEnvelope } from '../../api/SubsonicTypes';
import { TaskPoolRunner } from '../../concurrency/TaskPoolRunner';

const SUBSONIC_ERR_PREFIX: string = 'SUBSONIC_ERR:';

export class SubsonicResponseParser {
  static parseEnvelope<T extends SubsonicEnvelope>(text: string): T {
    return SubsonicResponseParser.parseEnvelopeSync<T>(text);
  }

  static async parseEnvelopeAsync<T extends SubsonicEnvelope>(text: string): Promise<T> {
    try {
      return await TaskPoolRunner.parseSubsonicEnvelopeJson<T>(text);
    } catch (err) {
      throw SubsonicResponseParser.toApiError(err as Error);
    }
  }

  private static parseEnvelopeSync<T extends SubsonicEnvelope>(text: string): T {
    const raw: Object = JSON.parse(text) as Object;
    const entries: [string, Object][] = Object.entries(raw);
    let env: T | undefined;
    for (let i: number = 0; i < entries.length; i++) {
      if (entries[i][0] === 'subsonic-response') {
        env = entries[i][1] as T;
      }
    }
    if (env === undefined) {
      throw new SubsonicApiError(-1, 'Missing subsonic-response wrapper');
    }
    if (env.status === 'failed') {
      let errCode: number = -1;
      let errMsg: string = 'Unknown error';
      if (env.error !== undefined) {
        errCode = env.error.code;
        errMsg = env.error.message;
      }
      throw new SubsonicApiError(errCode, errMsg);
    }
    return env;
  }

  private static toApiError(err: Error): SubsonicApiError {
    const message: string = err.message;
    if (message.startsWith(SUBSONIC_ERR_PREFIX)) {
      const payload: string = message.substring(SUBSONIC_ERR_PREFIX.length);
      const colonIdx: number = payload.indexOf(':');
      if (colonIdx >= 0) {
        const codeText: string = payload.substring(0, colonIdx);
        const errMsg: string = payload.substring(colonIdx + 1);
        const errCode: number = parseInt(codeText, 10);
        return new SubsonicApiError(Number.isFinite(errCode) ? errCode : -1, errMsg);
      }
    }
    return new SubsonicApiError(0, message);
  }

  static isRetryableError(err: SubsonicApiError): boolean {
    if (err.code === 0) {
      return true;
    }
    if (err.code >= 500 && err.code < 600) {
      return true;
    }
    return false;
  }

  static isAuthError(err: SubsonicApiError): boolean {
    return err.code === 40 || err.code === 41;
  }

  static shouldFallbackFromLocal(err: SubsonicApiError): boolean {
    if (SubsonicResponseParser.isAuthError(err)) {
      return false;
    }
    return SubsonicResponseParser.isRetryableError(err);
  }
}
