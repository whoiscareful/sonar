import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

@Component
export struct CardContainer {
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .padding(12)
    .borderRadius(UiTokens.RADIUS_CARD)
    .backgroundColor(UiTokens.COLOR_CARD_BG)
    .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
    .border({ width: 1, color: UiTokens.COLOR_CARD_BORDER })
  }
}
