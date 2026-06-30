import { PLAYLIST_SHEET_SEQ_KEY } from './PlaylistSheetOpener';
import { PlaylistSheetController } from './PlaylistSheetController';

@Component
export struct PlaylistSheetHost {
  @StorageLink(PLAYLIST_SHEET_SEQ_KEY) @Watch('onSheetRequest') private sheetSeq: number = 0;
  private lastHandledSeq: number = 0;
  private readonly sheetController: PlaylistSheetController = PlaylistSheetController.getInstance();

  aboutToAppear(): void {
    AppStorage.setOrCreate<number>(PLAYLIST_SHEET_SEQ_KEY, 0);
    this.sheetController.attach(this.getUIContext());
  }

  aboutToDisappear(): void {
    this.sheetController.detach();
  }

  private onSheetRequest(): void {
    if (this.sheetSeq <= 0 || this.sheetSeq === this.lastHandledSeq) {
      return;
    }
    this.lastHandledSeq = this.sheetSeq;
    this.sheetController.openAtDetent();
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}
