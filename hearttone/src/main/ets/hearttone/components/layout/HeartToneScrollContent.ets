import { ImmersivePageOffsets } from '../../ui/layout/ImmersivePageOffsets';
import { HeartToneContentVariant, HeartTonePageRole } from '../../ui/layout/HeartTonePageLayoutOptions';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Builder
function emptyHeartToneScrollContent() {
}

/** 全站 Scroll 内容边距：Tab 根页 / 二级页共用，顶底距由 HeartTonePageRole 分发 */
@Component
export struct HeartToneScrollContent {
  @Prop role: HeartTonePageRole = HeartTonePageRole.TAB_ROOT;
  @Prop variant: HeartToneContentVariant = 'form';
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @StorageLink('rootTabActive') rootTabActive: boolean = false;
  @BuilderParam content: () => void = emptyHeartToneScrollContent;

  private topPadding(): number {
    return ImmersivePageOffsets.contentTopPadding(this.role, this.topInset, this.variant);
  }

  private bottomPadding(): number {
    return ImmersivePageOffsets.contentBottomPadding(this.role, this.bottomInset, this.rootTabActive);
  }

  build() {
    Column({ space: UiTokens.SECTION_GAP }) {
      this.content()
    }
    .width('100%')
    .constraintSize({ minHeight: '100%' })
    .padding({
      left: UiTokens.PAGE_HORIZONTAL_PADDING,
      right: UiTokens.PAGE_HORIZONTAL_PADDING,
      top: this.topPadding(),
      bottom: this.bottomPadding()
    })
    .linearGradient({
      angle: 160,
      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
    })
  }
}
