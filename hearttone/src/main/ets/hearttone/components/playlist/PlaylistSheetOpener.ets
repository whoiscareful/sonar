const PLAYLIST_SHEET_SEQ_KEY: string = 'playlistSheetSeq';

export class PlaylistSheetOpener {
  static requestOpen(): void {
    const current: number = AppStorage.get<number>(PLAYLIST_SHEET_SEQ_KEY) ?? 0;
    AppStorage.setOrCreate<number>(PLAYLIST_SHEET_SEQ_KEY, current + 1);
  }
}

export { PLAYLIST_SHEET_SEQ_KEY };
