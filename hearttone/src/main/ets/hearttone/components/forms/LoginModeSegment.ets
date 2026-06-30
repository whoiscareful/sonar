import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

@Component
export struct LoginModeSegment {
  @Prop selectedIndex: number = 0;
  @BuilderParam onSelect: (index: number) => void;

  @Builder
  segmentItem(label: string, index: number) {
    Text(label)
      .width('100%')
      .textAlign(TextAlign.Center)
      .fontSize(14)
      .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selectedIndex === index ? UiTokens.COLOR_TEXT_PRIMARY : UiTokens.COLOR_TEXT_SECONDARY)
      .padding({ top: 8, bottom: 8 })
      .borderRadius(10)
      .backgroundColor(this.selectedIndex === index ? UiTokens.COLOR_PRIMARY_SOFT_BG : Color.Transparent)
      .onClick(() => {
        if (this.onSelect !== undefined) {
          this.onSelect(index);
        }
      })
  }

  build() {
    Row() {
      Column() {
        this.segmentItem('服务器', 0)
      }
      .layoutWeight(1)

      Column() {
        this.segmentItem('导入', 1)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(4)
    .borderRadius(12)
    .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
    .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
    .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
  }
}
