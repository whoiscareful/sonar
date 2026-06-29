import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

/** 只读预览区字号，略小于默认可编辑 TextArea */
const READ_ONLY_FONT_SIZE: number = 14;

@Component
export struct AppTextArea {
  @Prop text: string = '';
  @Prop placeholder: string = '';
  @Prop areaHeight: number = 120;
  @Prop readOnly: boolean = false;
  @BuilderParam onValueChange: (value: string) => void;

  build() {
    Column() {
      TextArea({ text: this.text, placeholder: this.placeholder })
        .width('100%')
        .height('100%')
        .borderRadius(12)
        .backgroundColor(Color.Transparent)
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .fontSize(this.readOnly ? READ_ONLY_FONT_SIZE : 16)
        .fontColor(this.readOnly ? UiTokens.COLOR_TEXT_SECONDARY : UiTokens.COLOR_TEXT_PRIMARY)
        .placeholderColor(UiTokens.COLOR_TEXT_SECONDARY)
        .caretColor(UiTokens.COLOR_PRIMARY)
        .focusable(!this.readOnly)
        .enableKeyboardOnFocus(!this.readOnly)
        .selectionMenuHidden(this.readOnly)
        .copyOption(this.readOnly ? CopyOptions.None : CopyOptions.LocalDevice)
        .barState(this.readOnly ? BarState.Auto : BarState.Off)
        .onChange((value: string) => {
          if (!this.readOnly && this.onValueChange !== undefined) {
            this.onValueChange(value);
          }
        })
    }
    .width('100%')
    .height(this.areaHeight)
    .borderRadius(12)
    .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
    .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
    .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
  }
}
