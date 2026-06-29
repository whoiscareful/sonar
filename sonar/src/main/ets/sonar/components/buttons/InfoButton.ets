import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

@Component
export struct InfoButton {
  @Prop text: string = '';
  @BuilderParam onPressed: () => void;

  build() {
    Button(this.text)
      .height(30)
      .fontSize(12)
      .fontColor(UiTokens.COLOR_INFO)
      .fontWeight(FontWeight.Medium)
      .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
      .backgroundColor(UiTokens.COLOR_INFO_SOFT_BG)
      .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
      .borderRadius(UiTokens.RADIUS_CHIP)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        if (this.onPressed !== undefined) {
          this.onPressed();
        }
      })
  }
}
