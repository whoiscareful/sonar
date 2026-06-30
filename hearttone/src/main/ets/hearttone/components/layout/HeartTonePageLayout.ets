import { FloatingPageContent } from './FloatingPageContent';
import { HeartToneScrollContent } from './HeartToneScrollContent';
import {
  HeartToneContentVariant,
  HeartTonePageLayoutOptions,
  HeartTonePageRole,
  HeartToneScrollMode
} from '../../ui/layout/HeartTonePageLayoutOptions';
import { TabScrollerBridge } from '../../ui/layout/TabScrollerBridge';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Builder
function emptyHeartToneFloatingLayer() {
}

@Builder
function emptyHeartTonePageContent() {
}

/** 全站统一：可滚动内容 + 浮层（Tab 根页 / 独立页） */
@Component
export struct HeartTonePageLayout {
  @Prop options: HeartTonePageLayoutOptions = {
    role: HeartTonePageRole.TAB_ROOT,
    contentVariant: 'form',
    scrollMode: HeartToneScrollMode.SCROLL
  };
  @BuilderParam content: () => void = emptyHeartTonePageContent;
  @BuilderParam floatingLayer: () => void = emptyHeartToneFloatingLayer;
  @Consume('tabScrollerBridge') tabScrollerBridge: TabScrollerBridge = new TabScrollerBridge();

  private pageScroller(): Scroller {
    const tabIndex: number = this.options.barToneTabIndex ?? 0;
    return this.tabScrollerBridge.scrollerForTab(tabIndex);
  }

  private contentVariant(): HeartToneContentVariant {
    return this.options.contentVariant ?? 'form';
  }

  private scrollMode(): HeartToneScrollMode {
    return this.options.scrollMode ?? HeartToneScrollMode.SCROLL;
  }

  private barToneProbeId(): string {
    const tabIndex: number = this.options.barToneTabIndex ?? -1;
    if (tabIndex >= 0) {
      return `bar-tone-probe-${tabIndex}`;
    }
    return 'bar-tone-probe-inactive';
  }

  @LocalBuilder
  invokePageContent() {
    this.content();
  }

  @LocalBuilder
  invokeFloatingLayer() {
    this.floatingLayer();
  }

  @LocalBuilder
  buildWrappedContent() {
    if (this.options.role === HeartTonePageRole.STANDALONE) {
      FloatingPageContent({
        variant: this.contentVariant(),
        applySectionGap: false,
        content: this.invokePageContent
      });
    } else {
      HeartToneScrollContent({
        role: HeartTonePageRole.TAB_ROOT,
        variant: this.contentVariant(),
        content: this.invokePageContent
      });
    }
  }

  @Builder
  private buildScrollBody() {
    Scroll(this.pageScroller()) {
      Column() {
        this.buildWrappedContent();
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private buildStackBody() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.scrollMode() === HeartToneScrollMode.CUSTOM_BODY) {
        this.invokePageContent()
      } else {
        this.buildScrollBody()
      }
      this.invokeFloatingLayer()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      this.buildStackBody()
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .id(this.barToneProbeId())
  }
}
