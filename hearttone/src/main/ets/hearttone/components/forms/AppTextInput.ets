import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

@Component
export struct AppTextInput {
  @Prop text: string = '';
  @Prop placeholder: string = '';
  @Prop isPassword: boolean = false;
  @BuilderParam onValueChange: (value: string) => void;

  build() {
    Row() {
      TextInput({ text: this.text, placeholder: this.placeholder })
        .width('100%')
        .height('100%')
        .borderRadius(12)
        .backgroundColor(Color.Transparent)
        .padding({ left: 14, right: 14 })
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .placeholderColor(UiTokens.COLOR_TEXT_SECONDARY)
        .type(this.isPassword ? InputType.Password : InputType.Normal)
        .caretColor(UiTokens.COLOR_PRIMARY)
        .onChange((value: string) => {
          if (this.onValueChange !== undefined) {
            this.onValueChange(value);
          }
        })
    }
      .width('100%')
      .height(46)
      .borderRadius(12)
      .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
      .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
      .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
  }
}
