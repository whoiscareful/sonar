import { UiTokens } from '../tokens/UiTokens';

function resolveVpLength(context: UIContext, value: Length): number {
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') {
    if (value.endsWith('vp')) {
      return Number.parseFloat(value);
    }
    if (value.endsWith('px')) {
      return context.px2vp(Number.parseFloat(value));
    }
    const parsed: number = Number.parseFloat(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return 0;
}

export class LibraryGridLayout {
  static resolveColumns(contentWidthVp: number): number {
    const safeWidthVp: number = Math.max(0, contentWidthVp);
    const columnsByWidth: number = Math.floor(
      (safeWidthVp + UiTokens.LIBRARY_GRID_GAP) /
      (UiTokens.LIBRARY_CARD_MIN_WIDTH + UiTokens.LIBRARY_GRID_GAP)
    );
    return Math.max(
      UiTokens.LIBRARY_GRID_MIN_COLUMNS,
      Math.min(UiTokens.LIBRARY_GRID_MAX_COLUMNS, columnsByWidth)
    );
  }

  static lanesGap(): number {
    return UiTokens.LIBRARY_GRID_GAP;
  }

  /** List.space 不作用于 ListItemGroup 内部项，行间距须由 ListItem margin 承担 */
  static mainAxisItemGap(): number {
    return UiTokens.LIBRARY_GRID_GAP;
  }

  static contentWidthFromListArea(context: UIContext, listWidth: Length): number {
    const widthVp: number = resolveVpLength(context, listWidth);
    return Math.max(0, widthVp - UiTokens.LIBRARY_PAGE_HORIZONTAL_PADDING * 2);
  }
}
