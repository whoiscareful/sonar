import { ComponentContent, UIContext } from '@kit.ArkUI';
import { PlaylistSheet } from './PlaylistSheet';
import { UiTokens } from '../../ui/tokens/UiTokens';

export const PLAYLIST_SHEET_HEIGHT_MEDIUM_VP: number = 480;
export const PLAYLIST_SHEET_HEIGHT_LARGE_VP: number = 720;
export const PLAYLIST_SHEET_SCROLL_SEQ_KEY: string = 'playlistSheetScrollSeq';

type PlaylistSheetDetents = [number, number];

export const PLAYLIST_SHEET_DETENTS_VP: PlaylistSheetDetents = [
  PLAYLIST_SHEET_HEIGHT_MEDIUM_VP,
  PLAYLIST_SHEET_HEIGHT_LARGE_VP
];

const PLAYLIST_SHEET_CLOSE_THRESHOLD_VP: number = 120;
const PLAYLIST_SHEET_MIN_DRAG_OPEN_VP: number = 12;
const PLAYLIST_SHEET_SNAP_VELOCITY_VP: number = 500;

@Builder
function buildPlaylistSheetContent() {
  PlaylistSheet()
}

/**
 * 全局播放列表 Sheet 控制器：miniBar Pan 跟手拖拽 + 程序化打开。
 * 由 PlaylistSheetHost 在 aboutToAppear 时 attach UIContext。
 */
export class PlaylistSheetController {
  private static instance: PlaylistSheetController | null = null;

  private uiContext: UIContext | null = null;
  private sheetContent: ComponentContent<Object> | null = null;
  private sheetOpen: boolean = false;
  private isClosing: boolean = false;
  private currentHeightVp: number = 0;
  private dragAnchorHeightVp: number = 0;

  static getInstance(): PlaylistSheetController {
    if (PlaylistSheetController.instance === null) {
      PlaylistSheetController.instance = new PlaylistSheetController();
    }
    return PlaylistSheetController.instance;
  }

  attach(uiContext: UIContext): void {
    this.uiContext = uiContext;
    this.ensureContent();
    AppStorage.setOrCreate<number>(PLAYLIST_SHEET_SCROLL_SEQ_KEY, 0);
  }

  detach(): void {
    this.close();
    this.uiContext = null;
  }

  isSheetOpen(): boolean {
    return this.sheetOpen;
  }

  beginDrag(): void {
    if (this.isClosing) {
      return;
    }
    this.dragAnchorHeightVp = this.sheetOpen ? this.currentHeightVp : 0;
  }

  updateDragHeight(offsetY: number): void {
    if (this.uiContext === null || this.isClosing) {
      return;
    }
    const heightVp: number = this.clampHeight(this.dragAnchorHeightVp + (-offsetY));
    if (!this.sheetOpen) {
      if (heightVp < PLAYLIST_SHEET_MIN_DRAG_OPEN_VP) {
        return;
      }
      this.openAtHeight(heightVp);
      return;
    }
    if (Math.abs(heightVp - this.currentHeightVp) < 0.5) {
      return;
    }
    this.applyHeight(heightVp);
  }

  endDrag(offsetY: number, velocityY: number): void {
    if (this.uiContext === null || this.isClosing) {
      return;
    }
    const heightVp: number = this.clampHeight(this.dragAnchorHeightVp + (-offsetY));
    if (!this.sheetOpen) {
      return;
    }
    if (heightVp < PLAYLIST_SHEET_CLOSE_THRESHOLD_VP) {
      this.close();
      return;
    }
    this.applyHeight(this.resolveSnapHeight(heightVp, velocityY));
  }

  openAtDetent(detentVp: number = PLAYLIST_SHEET_HEIGHT_MEDIUM_VP): void {
    if (this.isClosing) {
      return;
    }
    if (this.sheetOpen) {
      this.applyHeight(detentVp);
      this.requestScrollToCurrent();
      return;
    }
    this.openAtHeight(detentVp);
  }

  close(): void {
    if (this.uiContext === null || this.sheetContent === null || !this.sheetOpen) {
      return;
    }
    this.isClosing = true;
    try {
      void this.uiContext.closeBindSheet(this.sheetContent);
    } catch (_err) {
      this.sheetOpen = false;
      this.isClosing = false;
      this.currentHeightVp = 0;
    }
  }

  private requestScrollToCurrent(): void {
    const current: number = AppStorage.get<number>(PLAYLIST_SHEET_SCROLL_SEQ_KEY) ?? 0;
    AppStorage.setOrCreate<number>(PLAYLIST_SHEET_SCROLL_SEQ_KEY, current + 1);
  }

  private ensureContent(): void {
    if (this.uiContext === null || this.sheetContent !== null) {
      return;
    }
    this.sheetContent = new ComponentContent(this.uiContext, wrapBuilder(buildPlaylistSheetContent));
  }

  private buildSheetOptions(heightVp: number): SheetOptions {
    const ctx: UIContext | null = this.uiContext;
    return {
      height: heightVp,
      detents: PLAYLIST_SHEET_DETENTS_VP,
      preferType: SheetType.BOTTOM,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      dragBar: true,
      backgroundColor: UiTokens.COLOR_PAGE_BG,
      onHeightDidChange: (heightPx: number): void => {
        if (ctx !== null) {
          this.currentHeightVp = ctx.px2vp(heightPx);
        }
      },
      onDisappear: (): void => {
        this.sheetOpen = false;
        this.isClosing = false;
        this.currentHeightVp = 0;
      }
    };
  }

  private openAtHeight(heightVp: number): void {
    this.ensureContent();
    if (this.uiContext === null || this.sheetContent === null || this.sheetOpen) {
      return;
    }
    const h: number = this.clampHeight(heightVp);
    this.currentHeightVp = h;
    this.sheetOpen = true;
    try {
      void this.uiContext.openBindSheet(this.sheetContent, this.buildSheetOptions(h));
      this.requestScrollToCurrent();
    } catch (_err) {
      this.sheetOpen = false;
      this.currentHeightVp = 0;
    }
  }

  private applyHeight(heightVp: number): void {
    this.ensureContent();
    if (this.uiContext === null || this.sheetContent === null || !this.sheetOpen) {
      return;
    }
    const h: number = this.clampHeight(heightVp);
    this.currentHeightVp = h;
    try {
      void this.uiContext.updateBindSheet(this.sheetContent, {
        height: h,
        detents: PLAYLIST_SHEET_DETENTS_VP
      }, true);
    } catch (_err) {
      // sheet may have been dismissed externally
    }
  }

  private clampHeight(heightVp: number): number {
    if (heightVp < 0) {
      return 0;
    }
    if (heightVp > PLAYLIST_SHEET_HEIGHT_LARGE_VP) {
      return PLAYLIST_SHEET_HEIGHT_LARGE_VP;
    }
    return heightVp;
  }

  private resolveSnapHeight(heightVp: number, velocityY: number): number {
    const medium: number = PLAYLIST_SHEET_HEIGHT_MEDIUM_VP;
    const large: number = PLAYLIST_SHEET_HEIGHT_LARGE_VP;
    const midpoint: number = (medium + large) / 2;
    if (velocityY < -PLAYLIST_SHEET_SNAP_VELOCITY_VP) {
      return large;
    }
    if (velocityY > PLAYLIST_SHEET_SNAP_VELOCITY_VP) {
      return medium;
    }
    if (heightVp >= midpoint) {
      return large;
    }
    return medium;
  }
}
