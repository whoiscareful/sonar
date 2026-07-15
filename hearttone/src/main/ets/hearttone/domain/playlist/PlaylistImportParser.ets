export type PlaylistImportMode = 'platform' | 'ai';

export interface ImportSongCandidate {
  title: string;
  artist: string;
  sourceText: string;
}

export class PlaylistImportParser {
  static parse(text: string, mode: PlaylistImportMode): ImportSongCandidate[] {
    const normalized: string = text.replace(/\r/g, '\n').replace(/\n+/g, '\n').trim();
    if (normalized.length === 0) {
      return [];
    }
    const fragments: string[] = mode === 'ai' ?
      normalized.split(/[\n，,、；;]/) : normalized.split('\n');
    const result: ImportSongCandidate[] = [];
    const seen: Set<string> = new Set<string>();
    for (let i: number = 0; i < fragments.length; i++) {
      const candidate: ImportSongCandidate | null = mode === 'ai' ?
        PlaylistImportParser.parseAiFragment(fragments[i]) :
        PlaylistImportParser.parsePlatformLine(fragments[i]);
      if (candidate === null || candidate.title.length === 0) {
        continue;
      }
      const key: string = `${PlaylistImportParser.normalize(candidate.title)}|${PlaylistImportParser.normalize(candidate.artist)}`;
      if (!seen.has(key)) {
        seen.add(key);
        result.push(candidate);
      }
      if (result.length >= 100) {
        break;
      }
    }
    return result;
  }

  private static parsePlatformLine(rawLine: string): ImportSongCandidate | null {
    let line: string = PlaylistImportParser.cleanLine(rawLine);
    if (line.length === 0 || PlaylistImportParser.isBoilerplate(line)) {
      return null;
    }
    const sourceText: string = line;
    const separators: string[] = [' — ', ' – ', ' - ', '｜', '|', '\t'];
    for (let i: number = 0; i < separators.length; i++) {
      const index: number = line.indexOf(separators[i]);
      if (index > 0 && index < line.length - separators[i].length) {
        const title: string = line.substring(0, index).trim();
        const artist: string = line.substring(index + separators[i].length).trim();
        return PlaylistImportParser.candidate(title, artist, sourceText);
      }
    }
    const bracketStart: number = line.indexOf('《');
    const bracketEnd: number = line.indexOf('》');
    if (bracketStart >= 0 && bracketEnd > bracketStart) {
      const title: string = line.substring(bracketStart + 1, bracketEnd).trim();
      const artist: string = line.substring(bracketEnd + 1).replace(/^[-—–：:\s]+/, '').trim();
      return PlaylistImportParser.candidate(title, artist, sourceText);
    }
    return PlaylistImportParser.candidate(line, '', sourceText);
  }

  private static parseAiFragment(rawFragment: string): ImportSongCandidate | null {
    const fragment: string = PlaylistImportParser.cleanLine(rawFragment)
      .replace(/^(请|帮我|加入|添加|导入|想听|歌曲|歌名)[:：\s]*/, '')
      .trim();
    if (fragment.length === 0 || PlaylistImportParser.isBoilerplate(fragment)) {
      return null;
    }
    const possessiveIndex: number = fragment.indexOf('的');
    if (possessiveIndex > 0 && possessiveIndex < fragment.length - 1) {
      const artist: string = fragment.substring(0, possessiveIndex).replace(/[《》]/g, '').trim();
      const title: string = fragment.substring(possessiveIndex + 1).replace(/[《》]/g, '').trim();
      return PlaylistImportParser.candidate(title, artist, fragment);
    }
    return PlaylistImportParser.parsePlatformLine(fragment);
  }

  private static cleanLine(rawLine: string): string {
    return rawLine
      .replace(/^\s*\d+[\.、\)）]\s*/, '')
      .replace(/^\s*[•·#]\s*/, '')
      .replace(/\s+\d{1,2}:\d{2}\s*$/, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private static isBoilerplate(line: string): boolean {
    const lower: string = line.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return true;
    }
    return line.indexOf('歌单') >= 0 && (line.indexOf('分享') >= 0 || line.indexOf('共') >= 0) ||
      line === '歌曲' || line === '歌手' || line === '歌曲名' || line === '音乐标题' ||
      lower === 'title' || lower === 'artist';
  }

  private static candidate(title: string, artist: string, sourceText: string): ImportSongCandidate {
    const value: ImportSongCandidate = {
      title: title.replace(/^[《“\"]+|[》”\"]+$/g, '').trim(),
      artist: artist.replace(/^[《“\"]+|[》”\"]+$/g, '').trim(),
      sourceText: sourceText
    };
    return value;
  }

  private static normalize(value: string): string {
    return value.toLowerCase().replace(/[\s\-—–_·\.，,。'"《》“”‘’（）()]/g, '');
  }
}
