import { http } from '@kit.NetworkKit';
import { ImportSongCandidate } from './PlaylistImportParser';

export type PlaylistPlatform = 'netease' | 'qq' | 'huawei' | 'apple' | 'spotify' | 'kugou' | 'kuwo';

export interface PlatformPlaylistImportResult {
  platform: PlaylistPlatform;
  platformName: string;
  playlistName: string;
  candidates: ImportSongCandidate[];
}

interface NeteaseArtist {
  name: string;
}

interface NeteaseTrack {
  name: string;
  artists?: NeteaseArtist[];
  ar?: NeteaseArtist[];
}

interface NeteasePlaylist {
  name: string;
  tracks: NeteaseTrack[];
}

interface NeteaseResponse {
  code: number;
  playlist?: NeteasePlaylist;
  result?: NeteasePlaylist;
}

interface QqSinger {
  name: string;
}

interface QqTrack {
  songname?: string;
  title?: string;
  singer?: QqSinger[];
}

interface QqPlaylist {
  dissname: string;
  songlist: QqTrack[];
}

interface QqResponse {
  code: number;
  cdlist?: QqPlaylist[];
}

interface HuaweiResult {
  resultCode: string;
  resultMessage?: string;
}

interface HuaweiPlaylistDetail {
  contentName?: string;
  totalCount?: string;
}

interface HuaweiSong {
  contentName?: string;
  artistName?: string;
}

interface HuaweiMusicListInfoEx {
  musicListDetail?: HuaweiPlaylistDetail;
  songSimpleInfos?: HuaweiSong[];
}

interface HuaweiPlaylistResponse {
  result?: HuaweiResult;
  musicListInfoEx?: HuaweiMusicListInfoEx;
}

interface HuaweiPlaylistRequest {
  musicListID: string;
  start: number;
  limit: number;
}

const SUPPORTED_PLATFORM_TEXT: string =
  '网易云音乐、QQ 音乐、华为音乐、Apple Music、Spotify、酷狗音乐、酷我音乐';
const MAX_IMPORTED_SONGS: number = 200;

export class PlatformPlaylistImporter {
  static supportedPlatformText(): string {
    return SUPPORTED_PLATFORM_TEXT;
  }

  static async importFromShareText(sourceText: string): Promise<PlatformPlaylistImportResult> {
    const url: string = PlatformPlaylistImporter.extractUrl(sourceText);
    if (url.length === 0) {
      throw new Error('请粘贴歌单分享链接');
    }
    const platform: PlaylistPlatform = PlatformPlaylistImporter.detectPlatform(url);
    if (platform === 'netease') {
      return await PlatformPlaylistImporter.importNetease(url);
    }
    if (platform === 'qq') {
      return await PlatformPlaylistImporter.importQq(url);
    }
    if (platform === 'huawei') {
      return await PlatformPlaylistImporter.importHuawei(url);
    }
    return await PlatformPlaylistImporter.importPublicPage(url, platform);
  }

  private static extractUrl(text: string): string {
    const match: RegExpMatchArray | null = text.match(/https?:\/\/[^\s<>]+/i);
    if (match === null || match.length === 0) {
      return '';
    }
    return match[0].replace(/[，。；、）》】}'"]+$/g, '');
  }

  private static detectPlatform(url: string): PlaylistPlatform {
    const normalized: string = url.toLowerCase();
    if (normalized.indexOf('music.163.com') >= 0 || normalized.indexOf('163cn.tv') >= 0 ||
      normalized.indexOf('music.126.net') >= 0) {
      return 'netease';
    }
    if (normalized.indexOf('y.qq.com') >= 0 || normalized.indexOf('i.y.qq.com') >= 0 ||
      normalized.indexOf('c.y.qq.com') >= 0 || normalized.indexOf('qm.qq.com') >= 0) {
      return 'qq';
    }
    if (normalized.indexOf('music.apple.com') >= 0) {
      return 'apple';
    }
    if (normalized.indexOf('open.spotify.com') >= 0) {
      return 'spotify';
    }
    if (normalized.indexOf('kugou.com') >= 0 || normalized.indexOf('kugou.net') >= 0) {
      return 'kugou';
    }
    if (normalized.indexOf('kuwo.cn') >= 0) {
      return 'kuwo';
    }
    if (normalized.indexOf('url.cloud.huawei.com') >= 0 || normalized.indexOf('music.huawei.com') >= 0 ||
      normalized.indexOf('music.cloud.huawei.com') >= 0 ||
      normalized.indexOf('dbankcdn.com') >= 0) {
      return 'huawei';
    }
    throw new Error(`暂不支持该链接。当前支持：${SUPPORTED_PLATFORM_TEXT}`);
  }

  private static platformName(platform: PlaylistPlatform): string {
    if (platform === 'netease') {
      return '网易云音乐';
    }
    if (platform === 'qq') {
      return 'QQ 音乐';
    }
    if (platform === 'huawei') {
      return '华为音乐';
    }
    if (platform === 'apple') {
      return 'Apple Music';
    }
    if (platform === 'spotify') {
      return 'Spotify';
    }
    if (platform === 'kugou') {
      return '酷狗音乐';
    }
    return '酷我音乐';
  }

  private static async importNetease(shareUrl: string): Promise<PlatformPlaylistImportResult> {
    let id: string = PlatformPlaylistImporter.extractDigits(shareUrl,
      /(?:playlist\?id=|playlist\/|playlistId["'=:\s]+)(\d+)/i);
    if (id.length === 0) {
      const sharePage: string = await PlatformPlaylistImporter.requestText(shareUrl, 'https://music.163.com/');
      id = PlatformPlaylistImporter.extractDigits(sharePage,
        /(?:playlist\?id=|playlist\/|playlistId["'=:\s]+)(\d+)/i);
    }
    if (id.length === 0) {
      throw new Error('未能从网易云音乐分享链接中识别歌单编号');
    }
    const raw: string = await PlatformPlaylistImporter.requestText(
      `https://music.163.com/api/playlist/detail?id=${id}&n=${MAX_IMPORTED_SONGS}`,
      'https://music.163.com/'
    );
    const response: NeteaseResponse = JSON.parse(raw) as NeteaseResponse;
    const playlist: NeteasePlaylist | undefined = response.playlist ?? response.result;
    if (response.code !== 200 || playlist === undefined || !Array.isArray(playlist.tracks)) {
      throw new Error('网易云音乐未返回该歌单，可能是私密歌单或链接已失效');
    }
    const candidates: ImportSongCandidate[] = [];
    const count: number = Math.min(MAX_IMPORTED_SONGS, playlist.tracks.length);
    for (let i: number = 0; i < count; i++) {
      const track: NeteaseTrack = playlist.tracks[i];
      const artists: NeteaseArtist[] = track.ar ?? track.artists ?? [];
      PlatformPlaylistImporter.addCandidate(candidates, track.name,
        PlatformPlaylistImporter.joinNeteaseArtists(artists));
    }
    return PlatformPlaylistImporter.result('netease', playlist.name, candidates);
  }

  private static async importQq(shareUrl: string): Promise<PlatformPlaylistImportResult> {
    let id: string = PlatformPlaylistImporter.extractDigits(shareUrl,
      /(?:playlist\/|taoge\.html\?id=|[?&](?:id|disstid)=)(\d+)/i);
    if (id.length === 0) {
      const sharePage: string = await PlatformPlaylistImporter.requestText(shareUrl, 'https://y.qq.com/');
      id = PlatformPlaylistImporter.extractDigits(sharePage,
        /(?:playlist\/|taoge\.html\?id=|(?:id|disstid)["'=:\s]+)(\d+)/i);
    }
    if (id.length === 0) {
      throw new Error('未能从 QQ 音乐分享链接中识别歌单编号');
    }
    const endpoint: string = 'https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg?' +
      `type=1&json=1&utf8=1&onlysong=0&disstid=${id}&format=json`;
    const raw: string = await PlatformPlaylistImporter.requestText(endpoint, 'https://y.qq.com/');
    const response: QqResponse = JSON.parse(raw) as QqResponse;
    if (response.code !== 0 || response.cdlist === undefined || response.cdlist.length === 0) {
      throw new Error('QQ 音乐未返回该歌单，可能是私密歌单或链接已失效');
    }
    const playlist: QqPlaylist = response.cdlist[0];
    const candidates: ImportSongCandidate[] = [];
    const count: number = Math.min(MAX_IMPORTED_SONGS, playlist.songlist.length);
    for (let i: number = 0; i < count; i++) {
      const track: QqTrack = playlist.songlist[i];
      PlatformPlaylistImporter.addCandidate(candidates, track.songname ?? track.title ?? '',
        PlatformPlaylistImporter.joinQqArtists(track.singer ?? []));
    }
    return PlatformPlaylistImporter.result('qq', playlist.dissname, candidates);
  }

  private static async importHuawei(shareUrl: string): Promise<PlatformPlaylistImportResult> {
    const idMatch: RegExpMatchArray | null = shareUrl.match(/[?&#]id=([^&#]+)/i);
    if (idMatch === null || idMatch.length < 2) {
      throw new Error('未能从华为音乐分享链接中识别歌单编号');
    }
    let musicListId: string = idMatch[1];
    try {
      musicListId = decodeURIComponent(musicListId);
    } catch (_err) {
    }
    const endpoint: string = 'https://portal-drcn.music.cloud.huawei.com/' +
      'music-operation-service/v2/service/musiclist/detail/bymusiclistid';
    const candidates: ImportSongCandidate[] = [];
    let playlistName: string = '';
    let start: number = 0;
    const pageSize: number = 20;
    let totalCount: number = MAX_IMPORTED_SONGS;
    while (start < totalCount && candidates.length < MAX_IMPORTED_SONGS) {
      const payload: HuaweiPlaylistRequest = {
        musicListID: musicListId,
        start: start,
        limit: Math.min(pageSize, MAX_IMPORTED_SONGS - candidates.length)
      };
      const raw: string = await PlatformPlaylistImporter.requestJsonPost(endpoint, payload,
        'https://portal-drcn.music.cloud.huawei.com/music-apph5-service/musich5/index.html');
      const response: HuaweiPlaylistResponse = JSON.parse(raw) as HuaweiPlaylistResponse;
      if (response.result?.resultCode !== '000000' || response.musicListInfoEx === undefined) {
        throw new Error(response.result?.resultMessage ?? '华为音乐未返回该歌单');
      }
      const detail: HuaweiPlaylistDetail | undefined = response.musicListInfoEx.musicListDetail;
      if (playlistName.length === 0) {
        playlistName = detail?.contentName ?? '';
      }
      if (detail?.totalCount !== undefined) {
        const parsedTotal: number = Number(detail.totalCount);
        if (!Number.isNaN(parsedTotal)) {
          totalCount = Math.min(MAX_IMPORTED_SONGS, parsedTotal);
        }
      }
      const songs: HuaweiSong[] = response.musicListInfoEx.songSimpleInfos ?? [];
      for (let i: number = 0; i < songs.length && candidates.length < MAX_IMPORTED_SONGS; i++) {
        PlatformPlaylistImporter.addCandidate(candidates, songs[i].contentName ?? '', songs[i].artistName ?? '');
      }
      if (songs.length === 0 || songs.length < pageSize) {
        break;
      }
      start += songs.length;
    }
    return PlatformPlaylistImporter.result('huawei', playlistName, candidates);
  }

  private static async importPublicPage(url: string,
    platform: PlaylistPlatform): Promise<PlatformPlaylistImportResult> {
    const html: string = await PlatformPlaylistImporter.requestText(url, url);
    const candidates: ImportSongCandidate[] = [];
    if (platform === 'apple') {
      PlatformPlaylistImporter.collectAppleTracks(html, candidates);
    } else if (platform === 'spotify') {
      PlatformPlaylistImporter.collectSpotifyTracks(html, candidates);
    } else if (platform === 'huawei') {
      PlatformPlaylistImporter.collectJsonPairs(html, candidates, 'songName', 'singerName');
      PlatformPlaylistImporter.collectJsonPairs(html, candidates, 'trackName', 'artistName');
      PlatformPlaylistImporter.collectJsonPairs(html, candidates, 'name', 'singer');
    } else if (platform === 'kugou') {
      PlatformPlaylistImporter.collectJsonPairs(html, candidates, 'songname', 'singername');
      PlatformPlaylistImporter.collectJsonPairs(html, candidates, 'songName', 'singerName');
      PlatformPlaylistImporter.collectJsonPairs(html, candidates, 'name', 'singer');
    } else {
      PlatformPlaylistImporter.collectJsonPairs(html, candidates, 'name', 'artist');
      PlatformPlaylistImporter.collectJsonPairs(html, candidates, 'songName', 'artistName');
    }
    if (candidates.length === 0) {
      throw new Error(`${PlatformPlaylistImporter.platformName(platform)}公开分享页未返回歌曲明细，` +
        '请确认链接可在未登录状态下打开');
    }
    return PlatformPlaylistImporter.result(platform, PlatformPlaylistImporter.extractPlaylistName(html), candidates);
  }

  private static collectAppleTracks(html: string, output: ImportSongCandidate[]): void {
    const expression: RegExp = /"artistName":"((?:\\.|[^"\\])*)"[\s\S]{0,1200}?"fields":\{[\s\S]{0,500}?"name":"((?:\\.|[^"\\])*)"/g;
    let match: RegExpExecArray | null = expression.exec(html);
    while (match !== null && output.length < MAX_IMPORTED_SONGS) {
      PlatformPlaylistImporter.addCandidate(output,
        PlatformPlaylistImporter.decodeJsonString(match[2]),
        PlatformPlaylistImporter.decodeJsonString(match[1]));
      match = expression.exec(html);
    }
  }

  private static collectSpotifyTracks(html: string, output: ImportSongCandidate[]): void {
    const expression: RegExp = /href="\/track\/[^"?]+"[\s\S]{0,800}?data-encore-id="listRowTitle"[\s\S]{0,400}?<span[^>]*>([^<]+)<\/span>[\s\S]{0,800}?href="\/artist\/[^"?]+">([^<]+)<\/a>/g;
    let match: RegExpExecArray | null = expression.exec(html);
    while (match !== null && output.length < MAX_IMPORTED_SONGS) {
      PlatformPlaylistImporter.addCandidate(output,
        PlatformPlaylistImporter.decodeHtml(match[1]),
        PlatformPlaylistImporter.decodeHtml(match[2]));
      match = expression.exec(html);
    }
  }

  private static collectJsonPairs(html: string, output: ImportSongCandidate[],
    titleKey: string, artistKey: string): void {
    const titleFirst: RegExp = new RegExp(`"${titleKey}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"` +
      `[\\s\\S]{0,900}?"${artistKey}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"`, 'g');
    PlatformPlaylistImporter.collectPairMatches(html, output, titleFirst, false);
    const artistFirst: RegExp = new RegExp(`"${artistKey}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"` +
      `[\\s\\S]{0,900}?"${titleKey}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"`, 'g');
    PlatformPlaylistImporter.collectPairMatches(html, output, artistFirst, true);
  }

  private static collectPairMatches(html: string, output: ImportSongCandidate[], expression: RegExp,
    reversed: boolean): void {
    let match: RegExpExecArray | null = expression.exec(html);
    while (match !== null && output.length < MAX_IMPORTED_SONGS) {
      PlatformPlaylistImporter.addCandidate(output,
        PlatformPlaylistImporter.decodeJsonString(reversed ? match[2] : match[1]),
        PlatformPlaylistImporter.decodeJsonString(reversed ? match[1] : match[2]));
      match = expression.exec(html);
    }
  }

  private static extractPlaylistName(html: string): string {
    const jsonLd: RegExpMatchArray | null = html.match(/"@type":"MusicPlaylist"[\s\S]{0,800}?"name":"((?:\\.|[^"\\])*)"/);
    if (jsonLd !== null) {
      return PlatformPlaylistImporter.decodeJsonString(jsonLd[1]);
    }
    const ogTitle: RegExpMatchArray | null = html.match(/<meta[^>]+property="og:title"[^>]+content="([^"]+)"/i);
    if (ogTitle !== null) {
      return PlatformPlaylistImporter.decodeHtml(ogTitle[1]);
    }
    const title: RegExpMatchArray | null = html.match(/<title[^>]*>([^<]+)<\/title>/i);
    return title === null ? '导入歌单' : PlatformPlaylistImporter.decodeHtml(title[1]);
  }

  private static result(platform: PlaylistPlatform, playlistName: string,
    candidates: ImportSongCandidate[]): PlatformPlaylistImportResult {
    if (candidates.length === 0) {
      throw new Error('歌单中没有可读取的歌曲');
    }
    const value: PlatformPlaylistImportResult = {
      platform: platform,
      platformName: PlatformPlaylistImporter.platformName(platform),
      playlistName: playlistName.trim().length > 0 ? playlistName.trim() : `${PlatformPlaylistImporter.platformName(platform)}歌单`,
      candidates: candidates
    };
    return value;
  }

  private static addCandidate(output: ImportSongCandidate[], title: string, artist: string): void {
    const normalizedTitle: string = PlatformPlaylistImporter.cleanText(title);
    const normalizedArtist: string = PlatformPlaylistImporter.cleanText(artist);
    if (normalizedTitle.length === 0 || normalizedTitle.length > 180) {
      return;
    }
    const duplicate: boolean = output.some((item: ImportSongCandidate) =>
      item.title.toLowerCase() === normalizedTitle.toLowerCase() &&
      item.artist.toLowerCase() === normalizedArtist.toLowerCase());
    if (duplicate) {
      return;
    }
    output.push({
      title: normalizedTitle,
      artist: normalizedArtist,
      sourceText: normalizedArtist.length > 0 ? `${normalizedTitle} - ${normalizedArtist}` : normalizedTitle
    });
  }

  private static cleanText(value: string): string {
    return PlatformPlaylistImporter.decodeHtml(value).replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
  }

  private static decodeJsonString(value: string): string {
    try {
      return JSON.parse(`"${value}"`) as string;
    } catch (_err) {
      return value.replace(/\\"/g, '"').replace(/\\\//g, '/');
    }
  }

  private static decodeHtml(value: string): string {
    let result: string = value
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#x27;/g, "'")
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&nbsp;/g, ' ');
    const numeric: RegExp = /&#(x?[0-9a-fA-F]+);/g;
    let match: RegExpExecArray | null = numeric.exec(result);
    while (match !== null) {
      const radix: number = match[1].startsWith('x') || match[1].startsWith('X') ? 16 : 10;
      const digits: string = radix === 16 ? match[1].slice(1) : match[1];
      result = result.replace(match[0], String.fromCharCode(parseInt(digits, radix)));
      numeric.lastIndex = 0;
      match = numeric.exec(result);
    }
    return result;
  }

  private static extractDigits(value: string, expression: RegExp): string {
    const match: RegExpMatchArray | null = value.match(expression);
    return match === null || match.length < 2 ? '' : match[1];
  }

  private static joinNeteaseArtists(artists: NeteaseArtist[]): string {
    const names: string[] = [];
    for (let i: number = 0; i < artists.length; i++) {
      if (artists[i].name.length > 0) {
        names.push(artists[i].name);
      }
    }
    return names.join(' / ');
  }

  private static joinQqArtists(artists: QqSinger[]): string {
    const names: string[] = [];
    for (let i: number = 0; i < artists.length; i++) {
      if (artists[i].name.length > 0) {
        names.push(artists[i].name);
      }
    }
    return names.join(' / ');
  }

  private static async requestText(url: string, referer: string): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json,text/html,application/xhtml+xml,*/*',
          'Referer': referer,
          'User-Agent': 'Mozilla/5.0 (HarmonyOS; HeartTone) AppleWebKit/537.36'
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 12000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 400) {
        throw new Error(`分享页请求失败（HTTP ${response.responseCode}）`);
      }
      return response.result as string;
    } finally {
      request.destroy();
    }
  }

  private static async requestJsonPost(url: string, payload: HuaweiPlaylistRequest,
    referer: string): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Accept': 'application/json, text/plain, */*',
          'Content-Type': 'application/json; charset=utf-8',
          'Origin': 'https://portal-drcn.music.cloud.huawei.com',
          'Referer': referer,
          'User-Agent': 'Mozilla/5.0 (HarmonyOS; HeartTone) AppleWebKit/537.36'
        },
        extraData: JSON.stringify(payload),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 12000,
        readTimeout: 30000
      });
      if (response.responseCode < 200 || response.responseCode >= 400) {
        throw new Error(`华为音乐请求失败（HTTP ${response.responseCode}）`);
      }
      return response.result as string;
    } finally {
      request.destroy();
    }
  }
}
