import { SubsonicApiError } from '../../api/SubsonicTypes';

export class SubsonicUrlUtil {
  static normalizeServerUrl(rawUrl: string): string {
    const trimmed: string = rawUrl.trim();
    if (trimmed.length === 0) {
      throw new SubsonicApiError(-2, '服务器地址不能为空');
    }
    const matched: RegExpMatchArray | null = trimmed.match(/^(https?):\/\/([^/\s]+)(\/[^\s]*)?$/i);
    if (matched === null) {
      throw new SubsonicApiError(-2, '服务器地址格式不正确，请使用 http(s)://host[:port][/path]');
    }
    const normalizedPath: string = (matched[3] ?? '').replace(/\/+$/, '');
    return `${matched[1].toLowerCase()}://${matched[2]}${normalizedPath}`;
  }
}
