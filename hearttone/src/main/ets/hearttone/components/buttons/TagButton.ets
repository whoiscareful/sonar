import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

export interface TagButtonMenuItem {
  value: string;
  action: () => void;
}

@Extend(Button)
function immersiveChipStyle(fontColor: ResourceColor, bgColor: ResourceColor) {
  .height(30)
  .fontSize(12)
  .fontColor(fontColor)
  .fontWeight(FontWeight.Medium)
  .backgroundColor(bgColor)
  .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
  .borderRadius(UiTokens.RADIUS_CHIP)
  .padding({ left: 12, right: 12 })
  .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
}

@Component
export struct TagButton {
  @Prop text: string = '';
  @Prop fontColor: ResourceColor = UiTokens.COLOR_PRIMARY;
  @Prop bgColor: ResourceColor = UiTokens.COLOR_PRIMARY_SOFT_BG;
  @Prop menuItems: TagButtonMenuItem[] = [];
  @BuilderParam onPressed: () => void;

  build() {
    if (this.menuItems.length > 0) {
      Button(this.text)
        .immersiveChipStyle(this.fontColor, this.bgColor)
        .hitTestBehavior(HitTestMode.Block)
        .accessibilityText(this.text)
        .bindMenu(this.menuItems)
    } else {
      Button(this.text)
        .immersiveChipStyle(this.fontColor, this.bgColor)
        .onClick(() => {
          if (this.onPressed !== undefined) {
            this.onPressed();
          }
        })
    }
  }
}
