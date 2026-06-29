import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SonarScrollContent } from '../layout/SonarScrollContent';
import { HdsPageTitleBar } from '../../ui/material/HdsPageTitleBar';
import { SonarContentVariant, SonarPageRole } from '../../ui/layout/SonarPageLayoutOptions';

@Builder
function emptySecondaryContent() {
}

@Builder
function emptySecondaryFloatingLayer() {
}

/** 二级页：HdsNavDestination 直包 Scroll + IMMERSIVE_GRADIENT_BLUR + bindToScrollable（官方骨架） */
@Component
export struct SecondaryHdsDestination {
  @Prop title: string = '';
  @Prop contentVariant: SonarContentVariant = 'form';
  @StorageLink('currentColorMode') currentColorMode: number = 0;
  private scroller: Scroller = new Scroller();
  @BuilderParam content: () => void = emptySecondaryContent;
  @BuilderParam floatingLayer: () => void = emptySecondaryFloatingLayer;

  @LocalBuilder
  invokeDestinationContent() {
    this.content();
  }

  @LocalBuilder
  buildScrollContent() {
    SonarScrollContent({
      role: SonarPageRole.NAV_STACK,
      variant: this.contentVariant,
      content: this.invokeDestinationContent
    });
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll(this.scroller) {
          this.buildScrollContent();
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        this.floatingLayer();
      }
      .width('100%')
      .height('100%')
    }
    .id(`hds-dest-cm-${this.currentColorMode}`)
    .width('100%')
    .hideTitleBar(false)
    .hideBackButton(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(HdsPageTitleBar.buildSecondary(this.title))
    .systemBarStyle(
      HdsPageTitleBar.buildSystemBarOriginalStyle(),
      HdsPageTitleBar.buildSystemBarScrollStyle()
    )
    .bindToScrollable([this.scroller])
    .backgroundColor(Color.Transparent)
    .systemTransition(NavigationSystemTransitionType.CONTENT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
