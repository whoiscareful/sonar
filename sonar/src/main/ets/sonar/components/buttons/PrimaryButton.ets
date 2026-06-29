import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

@Component
export struct PrimaryButton {
  @Prop text: string = '';
  @Prop isEnabled: boolean = true;
  @Prop loading: boolean = false;
  @BuilderParam onPressed: () => void;

  build() {
    Button(this.loading ? '处理中…' : this.text)
      .width('100%')
      .height(48)
      .fontSize(16)
      .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
      .fontWeight(FontWeight.Medium)
      .borderRadius(UiTokens.RADIUS_BUTTON)
      .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
      .backgroundColor(this.isEnabled && !this.loading ? UiTokens.COLOR_PRIMARY : UiTokens.COLOR_PRIMARY_DISABLED_BG)
      .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
      .enabled(this.isEnabled && !this.loading)
      .onClick(() => {
        if (this.isEnabled && !this.loading) {
          if (this.onPressed !== undefined) {
            this.onPressed();
          }
        }
      })
  }
}
