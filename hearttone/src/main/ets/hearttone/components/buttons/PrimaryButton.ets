import { UiTokens } from '../../ui/tokens/UiTokens';

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
      .fontColor(this.isEnabled && !this.loading ? UiTokens.COLOR_TEXT_ON_BRAND : UiTokens.COLOR_TEXT_SECONDARY)
      .fontWeight(FontWeight.Medium)
      .borderRadius(UiTokens.RADIUS_BUTTON)
      .backgroundColor(this.isEnabled && !this.loading ? UiTokens.COLOR_ACTION_BG : UiTokens.COLOR_PRIMARY_DISABLED_BG)
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
