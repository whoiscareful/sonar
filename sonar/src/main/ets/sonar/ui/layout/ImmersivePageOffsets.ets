import { SonarContentVariant, SonarPageRole } from './SonarPageLayoutOptions';
import { UiTokens } from '../tokens/UiTokens';

export class ImmersivePageOffsets {
  /** Tab 根页：底栏 + miniBar + 安全区 */
  static tabContentEnd(bottomInset: number, rootTabActive: boolean): number {
    if (rootTabActive) {
      return UiTokens.MINI_PLAYER_TAB_OFFSET + UiTokens.FLOATING_TAB_BAR_HEIGHT + bottomInset +
        UiTokens.LIBRARY_LIST_EDGE_GAP;
    }
    return UiTokens.FLOATING_TAB_BAR_HEIGHT + UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + bottomInset +
      UiTokens.LIBRARY_LIST_EDGE_GAP;
  }

  /** 二级页底部安全区 */
  static secondaryContentEnd(bottomInset: number): number {
    return bottomInset + UiTokens.LIBRARY_LIST_EDGE_GAP;
  }

  /** 二级页头部占位：状态栏 + MINI 标题栏 + 底缘冗余 */
  static secondaryHeaderOverlayHeight(topInset: number): number {
    return topInset + UiTokens.SECONDARY_HEADER_OVERLAY_VP;
  }

  /** 全站 Scroll 顶距入口：按页面角色分发 */
  static contentTopPadding(role: SonarPageRole, topInset: number,
    variant: SonarContentVariant = 'form'): number {
    if (role === SonarPageRole.NAV_STACK) {
      return ImmersivePageOffsets.secondaryContentTopPadding(topInset, variant);
    }
    return ImmersivePageOffsets.primaryContentTopPadding(topInset, variant);
  }

  /** 全站 Scroll 底距入口：按页面角色分发 */
  static contentBottomPadding(role: SonarPageRole, bottomInset: number, rootTabActive: boolean): number {
    if (role === SonarPageRole.NAV_STACK) {
      return ImmersivePageOffsets.secondaryContentEnd(bottomInset);
    }
    return ImmersivePageOffsets.tabContentEnd(bottomInset, rootTabActive);
  }

  /** Tab 根页：状态栏 + 首行间距（空标题栏不预留 MINI 56vp） */
  static primaryContentTopPadding(topInset: number, variant: SonarContentVariant = 'form'): number {
    const firstLineGap: number = variant === 'hero' ?
      UiTokens.CONTENT_TOP_GAP_HERO : UiTokens.CONTENT_TOP_GAP;
    return topInset + firstLineGap;
  }

  /** 二级页：状态栏 + 标题栏占位 + 首行间距 */
  static secondaryContentTopPadding(topInset: number, variant: SonarContentVariant = 'form'): number {
    const firstLineGap: number = variant === 'hero' ?
      UiTokens.CONTENT_TOP_GAP_HERO : UiTokens.CONTENT_TOP_GAP;
    return ImmersivePageOffsets.secondaryHeaderOverlayHeight(topInset) + firstLineGap;
  }

}
