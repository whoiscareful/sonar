import { SonarContentVariant } from '../../ui/layout/SonarPageLayoutOptions';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Builder
function emptyFloatingPageContent() {
}

/** 统一页面内容区边距与区块间距 */
@Component
export struct FloatingPageContent {
  @Prop variant: SonarContentVariant = 'form';
  @Prop applyHorizontalPadding: boolean = true;
  @Prop applyTopGap: boolean = true;
  @Prop applySectionGap: boolean = true;
  @BuilderParam content: () => void = emptyFloatingPageContent;

  private topGap(): number {
    if (!this.applyTopGap) {
      return 0;
    }
    if (this.variant === 'hero') {
      return UiTokens.CONTENT_TOP_GAP_HERO;
    }
    if (this.variant === 'login') {
      return 0;
    }
    return UiTokens.CONTENT_TOP_GAP;
  }

  build() {
    if (this.applySectionGap) {
      Column({ space: UiTokens.SECTION_GAP }) {
        this.content()
      }
      .width('100%')
      .padding(this.resolvePadding())
    } else {
      Column() {
        this.content()
      }
      .width('100%')
      .padding(this.resolvePadding())
    }
  }

  private resolvePadding(): Padding {
    if (this.variant === 'login') {
      return {
        left: UiTokens.LOGIN_HORIZONTAL_PADDING_PERCENT,
        right: UiTokens.LOGIN_HORIZONTAL_PADDING_PERCENT,
        top: this.topGap(),
        bottom: 48
      };
    }
    const horizontal: number = this.applyHorizontalPadding ? UiTokens.PAGE_HORIZONTAL_PADDING : 0;
    return {
      left: horizontal,
      right: horizontal,
      top: this.topGap()
    };
  }
}
