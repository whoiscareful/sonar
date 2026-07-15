import { SearchResponse, Song } from '../../api/SubsonicTypes';
import { MusicCatalogRepository } from '../music/MusicCatalogRepository';
import { ImportSongCandidate } from './PlaylistImportParser';

export interface MatchedImportSong {
  candidate: ImportSongCandidate;
  song: Song;
  score: number;
}

export interface SuggestedImportSong {
  candidate: ImportSongCandidate;
  options: MatchedImportSong[];
}

export interface PlaylistImportMatchResult {
  matched: MatchedImportSong[];
  suggestions: SuggestedImportSong[];
  unmatched: ImportSongCandidate[];
}

export class PlaylistImportMatcher {
  private readonly catalog: MusicCatalogRepository = MusicCatalogRepository.getInstance();

  async match(
    candidates: ImportSongCandidate[],
    onProgress?: (completed: number, total: number) => void
  ): Promise<PlaylistImportMatchResult> {
    const matched: MatchedImportSong[] = [];
    const suggestions: SuggestedImportSong[] = [];
    const unmatched: ImportSongCandidate[] = [];
    const matchedIds: Set<string> = new Set<string>();
    for (let i: number = 0; i < candidates.length; i++) {
      const candidate: ImportSongCandidate = candidates[i];
      try {
        // Search by title first. Artist is only used to rank songs with similar titles.
        const response: SearchResponse = await this.catalog.search(candidate.title, 0, 0, 12);
        const songs: Song[] = response.searchResult3?.song ?? [];
        const ranked: MatchedImportSong[] = PlaylistImportMatcher.rank(candidate, songs);
        let exact: MatchedImportSong | null = null;
        for (let j: number = 0; j < ranked.length; j++) {
          if (!matchedIds.has(ranked[j].song.id) &&
            PlaylistImportMatcher.isExactTitle(candidate, ranked[j].song)) {
            exact = ranked[j];
            break;
          }
        }
        if (exact !== null) {
          matchedIds.add(exact.song.id);
          matched.push(exact);
        } else {
          const options: MatchedImportSong[] = [];
          for (let j: number = 0; j < ranked.length && options.length < 3; j++) {
            if (!matchedIds.has(ranked[j].song.id) &&
              PlaylistImportMatcher.isPlausibleTitle(candidate, ranked[j].song)) {
              options.push(ranked[j]);
            }
          }
          if (options.length > 0) {
            suggestions.push({ candidate: candidate, options: options });
          } else {
            unmatched.push(candidate);
          }
        }
      } catch (_err) {
        unmatched.push(candidate);
      }
      if (onProgress !== undefined) {
        onProgress(i + 1, candidates.length);
      }
    }
    return { matched: matched, suggestions: suggestions, unmatched: unmatched };
  }

  private static rank(candidate: ImportSongCandidate, songs: Song[]): MatchedImportSong[] {
    const ranked: MatchedImportSong[] = [];
    for (let i: number = 0; i < songs.length; i++) {
      ranked.push({
        candidate: candidate,
        song: songs[i],
        score: PlaylistImportMatcher.score(candidate, songs[i])
      });
    }
    ranked.sort((left: MatchedImportSong, right: MatchedImportSong): number => right.score - left.score);
    return ranked;
  }

  private static score(candidate: ImportSongCandidate, song: Song): number {
    const expectedTitle: string = PlaylistImportMatcher.normalize(candidate.title);
    const actualTitle: string = PlaylistImportMatcher.normalize(song.title);
    const expectedArtist: string = PlaylistImportMatcher.normalize(candidate.artist);
    const actualArtist: string = PlaylistImportMatcher.normalize(song.artist);
    const similarity: number = PlaylistImportMatcher.titleSimilarity(expectedTitle, actualTitle);
    let score: number = Math.round(similarity * 700);
    if (expectedTitle === actualTitle && expectedTitle.length > 0) {
      score = 1000;
    }
    if (expectedArtist.length === 0) {
      return score;
    }
    if (expectedArtist === actualArtist) {
      return score + 100;
    }
    if (actualArtist.indexOf(expectedArtist) >= 0 || expectedArtist.indexOf(actualArtist) >= 0) {
      return score + 60;
    }
    return score;
  }

  private static isExactTitle(candidate: ImportSongCandidate, song: Song): boolean {
    const expected: string = PlaylistImportMatcher.normalize(candidate.title);
    return expected.length > 0 && expected === PlaylistImportMatcher.normalize(song.title);
  }

  private static isPlausibleTitle(candidate: ImportSongCandidate, song: Song): boolean {
    const expected: string = PlaylistImportMatcher.normalize(candidate.title);
    const actual: string = PlaylistImportMatcher.normalize(song.title);
    return expected !== actual && PlaylistImportMatcher.titleSimilarity(expected, actual) >= 0.45;
  }

  private static titleSimilarity(expected: string, actual: string): number {
    if (expected.length === 0 || actual.length === 0) {
      return 0;
    }
    if (expected === actual) {
      return 1;
    }
    if (actual.indexOf(expected) >= 0 || expected.indexOf(actual) >= 0) {
      return Math.min(expected.length, actual.length) / Math.max(expected.length, actual.length);
    }
    let common: number = 0;
    let remaining: string = actual;
    for (let i: number = 0; i < expected.length; i++) {
      const index: number = remaining.indexOf(expected[i]);
      if (index >= 0) {
        common++;
        remaining = remaining.slice(0, index) + remaining.slice(index + 1);
      }
    }
    return common / Math.max(expected.length, actual.length);
  }

  private static normalize(value: string): string {
    return value.toLowerCase().replace(/[\s\-—–·.，,。"'《》“”‘’（）()]/g, '');
  }
}
