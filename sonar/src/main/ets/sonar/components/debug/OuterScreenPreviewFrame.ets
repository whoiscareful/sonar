import { OuterScreenPlayerPage } from '../../pages/OuterScreenPlayerPage';
import { ScreenProfileStore } from '../../ui/adaptation/ScreenProfileStore';
import { OuterScreenPalette, OuterScreenTheme } from '../../ui/adaptation/OuterScreenTheme';
import { UiTokens } from '../../ui/tokens/UiTokens';

/**
 * 内屏「外屏预览」专用：机身留白 + 居中 1:1 方屏为外屏可视区，主题跟随系统深浅色。
 * 真外屏全屏时不使用本壳层。
 */
@Component
export struct OuterScreenPreviewFrame {
  @StorageLink('currentColorMode') currentColorMode: number = 0;
  @State private hostWidth: number = 360;
  @State private hostHeight: number = 780;

  private palette(): OuterScreenPalette {
    return OuterScreenTheme.palette(OuterScreenTheme.isDarkUi(this.currentColorMode));
  }

  private viewportSize(): number {
    const minHost: number = Math.min(this.hostWidth, this.hostHeight);
    return UiTokens.resolveOuterScreenPreviewViewportVp(minHost);
  }

  private cornerRadius(): number {
    return UiTokens.resolveOuterScreenPreviewCornerRadiusVp(this.viewportSize());
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.palette().bezel)
        .onClick(() => {
          ScreenProfileStore.setPreviewEnabled(false);
        })

      Column() {
        OuterScreenPlayerPage()
      }
      .width(this.viewportSize())
      .height(this.viewportSize())
      .borderRadius(this.cornerRadius())
      .clip(true)
      .linearGradient({
        angle: 160,
        colors: [[this.palette().bgGradientTop, 0], [this.palette().bgGradientBottom, 1]]
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette().bezel)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onAreaChange((_oldValue, newValue) => {
      if (typeof newValue.width === 'number' && newValue.width > 0) {
        this.hostWidth = newValue.width;
      }
      if (typeof newValue.height === 'number' && newValue.height > 0) {
        this.hostHeight = newValue.height;
      }
    })
  }
}
