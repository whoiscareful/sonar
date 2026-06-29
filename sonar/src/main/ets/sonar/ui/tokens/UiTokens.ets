export class UiTokens {
  static readonly TAB_BAR_CONTENT_EXTRA_PADDING: number = 16;

  static readonly COLOR_PRIMARY: ResourceColor = $r('app.color.sonar_primary');
  static readonly COLOR_PRIMARY_ON_LIGHT_BG: ResourceColor = $r('app.color.sonar_primary_on_light_bg');
  static readonly COLOR_PRIMARY_ON_DARK_BG: ResourceColor = $r('app.color.sonar_primary_on_dark_bg');
  static readonly COLOR_INFO: ResourceColor = $r('app.color.sonar_info');
  static readonly COLOR_SUCCESS: ResourceColor = $r('app.color.sonar_success');
  static readonly COLOR_DANGER: ResourceColor = $r('app.color.sonar_danger');
  static readonly COLOR_WARNING: ResourceColor = $r('app.color.sonar_warning');

  static readonly COLOR_BG_GRADIENT_TOP: ResourceColor = $r('app.color.sonar_bg_gradient_top');
  static readonly COLOR_BG_GRADIENT_BOTTOM: ResourceColor = $r('app.color.sonar_bg_gradient_bottom');
  static readonly COLOR_PAGE_BG: ResourceColor = $r('app.color.sonar_page_bg');

  static readonly COLOR_TEXT_PRIMARY: ResourceColor = $r('app.color.sonar_text_primary');
  static readonly COLOR_TEXT_SECONDARY: ResourceColor = $r('app.color.sonar_text_secondary');
  static readonly COLOR_TEXT_TERTIARY: ResourceColor = $r('app.color.sonar_text_tertiary');
  /** 歌手名（列表 / 播放列表等页面内统一；miniBar 见 COLOR_BAR_FG_SECONDARY_*） */
  static readonly COLOR_MUSIC_ARTIST: ResourceColor = $r('app.color.sonar_text_tertiary');

  static readonly COLOR_CARD_BG: ResourceColor = $r('app.color.sonar_card_bg');
  static readonly COLOR_CARD_BORDER: ResourceColor = $r('app.color.sonar_card_border');
  static readonly COLOR_PLACEHOLDER_BG: ResourceColor = $r('app.color.sonar_placeholder_bg');
  static readonly COLOR_GLASS_BAR_BG: ResourceColor = $r('app.color.sonar_glass_bar_bg');
  static readonly COLOR_GLASS_BAR_BORDER: ResourceColor = $r('app.color.sonar_glass_bar_border');

  static readonly COLOR_PRIMARY_SOFT_BG: ResourceColor = $r('app.color.sonar_primary_soft_bg');
  static readonly COLOR_INFO_SOFT_BG: ResourceColor = $r('app.color.sonar_info_soft_bg');
  static readonly COLOR_SUCCESS_SOFT_BG: ResourceColor = $r('app.color.sonar_success_soft_bg');
  static readonly COLOR_WARNING_SOFT_BG: ResourceColor = $r('app.color.sonar_warning_soft_bg');
  static readonly COLOR_DANGER_SOFT_BG: ResourceColor = $r('app.color.sonar_danger_soft_bg');
  static readonly COLOR_TAB_ICON_INACTIVE: ResourceColor = $r('app.color.sonar_tab_icon_inactive');
  static readonly COLOR_TAB_ICON_INACTIVE_ON_DARK_BG: ResourceColor =
    $r('app.color.sonar_tab_icon_inactive_on_dark_bg');
  static readonly COLOR_TAB_ICON_INACTIVE_ON_LIGHT_BG: ResourceColor =
    $r('app.color.sonar_tab_icon_inactive_on_light_bg');
  static readonly COLOR_BAR_FG_PRIMARY_ON_DARK_BG: ResourceColor = $r('app.color.sonar_bar_fg_primary_on_dark_bg');
  static readonly COLOR_BAR_FG_PRIMARY_ON_LIGHT_BG: ResourceColor = $r('app.color.sonar_bar_fg_primary_on_light_bg');
  static readonly COLOR_BAR_FG_SECONDARY_ON_DARK_BG: ResourceColor =
    $r('app.color.sonar_bar_fg_secondary_on_dark_bg');
  static readonly COLOR_BAR_FG_SECONDARY_ON_LIGHT_BG: ResourceColor =
    $r('app.color.sonar_bar_fg_secondary_on_light_bg');
  static readonly COLOR_OVERLAY_SCRIM: ResourceColor = $r('app.color.sonar_overlay_scrim');
  static readonly COLOR_DROPDOWN_TITLE: ResourceColor = $r('app.color.sonar_dropdown_title');
  static readonly COLOR_DROPDOWN_PANEL_BG: ResourceColor = $r('app.color.sonar_dropdown_panel_bg');
  static readonly COLOR_INPUT_BG: ResourceColor = $r('app.color.sonar_input_bg');
  static readonly COLOR_TEXT_ON_BRAND: ResourceColor = $r('app.color.sonar_text_on_brand');
  static readonly COLOR_TEXT_ON_BRAND_SECONDARY: ResourceColor = $r('app.color.sonar_text_on_brand_secondary');
  static readonly COLOR_SUCCESS_ALT: ResourceColor = $r('app.color.sonar_success_alt');
  static readonly COLOR_PRIMARY_DISABLED_BG: ResourceColor = $r('app.color.sonar_primary_disabled_bg');
  static readonly COLOR_ERROR: ResourceColor = $r('app.color.sonar_error');

  static readonly RADIUS_BUTTON: number = 14;
  static readonly RADIUS_CARD: number = 14;
  static readonly RADIUS_CHIP: number = 15;

  static readonly FLOATING_TAB_BAR_HEIGHT: number = 56;
  static readonly FLOATING_TAB_BAR_BOTTOM_MARGIN: number = 10;
  /** 底栏渐变蒙层额外高度（barFloatingStyle.gradientMask.maskHeight = TAB_HEIGHT + 此值） */
  static readonly FLOATING_TAB_GRADIENT_MASK_EXTRA: number = 32;
  /** 全站页面内容区水平边距（Tab / 二级表单） */
  static readonly PAGE_HORIZONTAL_PADDING: number = 16;
  /** 登录页水平边距（百分比） */
  static readonly LOGIN_HORIZONTAL_PADDING_PERCENT: string = '6%';
  /** 头部底缘到首行内容（form） */
  static readonly CONTENT_TOP_GAP: number = 12;
  /** 头部底缘到首行内容（hero 专辑头图） */
  static readonly CONTENT_TOP_GAP_HERO: number = 8;
  /** 页面内多卡片/段落间距 */
  static readonly SECTION_GAP: number = 12;
  /** HdsNavDestination MINI 标题栏控件区高度（不含状态栏，官方 56vp） */
  static readonly HDS_TITLE_BAR_MINI_HEIGHT: number = 56;
  /** 二级页标题栏底缘冗余留白（不含状态栏，全局统一） */
  static readonly SECONDARY_HEADER_BOTTOM_SLACK: number = 10;
  /** 二级页头部占位（不含状态栏）：MINI 标题栏 + 底缘冗余 */
  static readonly SECONDARY_HEADER_OVERLAY_VP: number =
    UiTokens.HDS_TITLE_BAR_MINI_HEIGHT + UiTokens.SECONDARY_HEADER_BOTTOM_SLACK;
  /** 二级页内容顶距（不含状态栏）：头部占位 + form 首行间距 */
  static readonly SECONDARY_CONTENT_PADDING_TOP_FORM: number =
    UiTokens.SECONDARY_HEADER_OVERLAY_VP + UiTokens.CONTENT_TOP_GAP;
  /** 二级页内容顶距（不含状态栏）：头部占位 + hero 首行间距 */
  static readonly SECONDARY_CONTENT_PADDING_TOP_HERO: number =
    UiTokens.SECONDARY_HEADER_OVERLAY_VP + UiTokens.CONTENT_TOP_GAP_HERO;
  /** 二级页浮层头部：上滑多少 vp 后毛玻璃满强度 */
  static readonly SECONDARY_GLASS_REVEAL_SCROLL_VP: number = 20;
  static readonly LIBRARY_SEARCH_HEIGHT: number = 48;
  /** 展开底栏总宽（页签+mini）：唯一调节点；见 .cursor/rules/hds/tabs-bar-floating.mdc「展开底部胶囊宽度」 */
  static readonly FLOATING_TAB_BAR_EXPANDED_WIDTH_SMALL: number = 262;
  static readonly FLOATING_TAB_BAR_EXPANDED_WIDTH_MEDIUM: number = 278;
  static readonly FLOATING_TAB_BAR_EXPANDED_WIDTH_LARGE: number = 294;
  static readonly DOCK_COVER_ROTATION_DURATION: number = 9000;
  static readonly MINI_BAR_BALL_COVER_INSET: number = 6;
  static readonly MINI_BAR_TITLE_FONT_SIZE: number = 14;
  static readonly MINI_BAR_ARTIST_FONT_SIZE: number = 12;
  static readonly MINI_BAR_TITLE_LINE_HEIGHT: number = 18;
  static readonly MINI_BAR_TEXT_LINE_GAP: number = 4;
  static readonly MINI_BAR_COVER_PLAY_ICON_SIZE: number = 18;
  static readonly MINI_BAR_COVER_CONTROL_HIDE_DELAY_MS: number = 2000;
  static readonly MINI_BAR_COVER_CONTROL_FADE_MS: number = 300;
  static readonly MINI_BAR_SWIPE_UP_THRESHOLD_VP: number = 40;
  /** miniBar 操作区与胶囊右缘内边距（与左侧封面球视觉留白对齐） */
  static readonly MINI_BAR_HORIZONTAL_INSET: number = 10;
  static readonly MINI_PLAYER_CAPSULE_CONTENT_GAP: number = 10;
  static readonly MINI_PLAYER_ACTION_TOUCH_SIZE: number = 34;
  static readonly MINI_PLAYER_ACTION_ICON_GAP: number = 6;
  static readonly BOTTOM_PADDING_WITH_TAB_BAR: number =
    UiTokens.FLOATING_TAB_BAR_HEIGHT + UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN +
    UiTokens.TAB_BAR_CONTENT_EXTRA_PADDING;
  static readonly MINI_PLAYER_TAB_OFFSET: number =
    UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + 12;
  static readonly MINI_PLAYER_BOTTOM_PADDING: number = 92;
  static readonly MINI_PLAYER_WITH_TAB_BOTTOM_PADDING: number = 96;

  static readonly LIBRARY_PAGE_HORIZONTAL_PADDING: number = 14;
  static readonly LIBRARY_LIST_EDGE_GAP: number = 8;
  static readonly LIBRARY_GRID_GAP: number = 12;
  static readonly LIBRARY_GRID_MIN_COLUMNS: number = 2;
  static readonly LIBRARY_GRID_MAX_COLUMNS: number = 3;
  static readonly LIBRARY_CARD_MIN_WIDTH: number = 158;
  static readonly LIBRARY_CARD_TITLE_HEIGHT: number = 22;
  /** 曲目列表：曲名区与右侧操作区间距 */
  static readonly MUSIC_LIST_TEXT_TRAILING_GAP: number = 10;
  static readonly MUSIC_LIST_TITLE_HEIGHT: number = 20;

  /** Pura X 外屏：1:1 方形判定容差 */
  static readonly OUTER_SCREEN_ASPECT_RATIO_MIN: number = 0.85;
  static readonly OUTER_SCREEN_ASPECT_RATIO_MAX: number = 1.15;
  /** 外屏紧凑边长上限（vp），Pura X 外屏官方 326vp，略留容差 */
  static readonly OUTER_SCREEN_MAX_COMPACT_EDGE: number = 340;
  static readonly OUTER_SCREEN_COVER_SIZE_RATIO: number = 0.62;
  static readonly OUTER_SCREEN_PLAY_MASK_SIZE: number = 56;
  static readonly OUTER_SCREEN_PLAY_ICON_SIZE: number = 28;
  static readonly OUTER_SCREEN_PLAY_MASK_COLOR: string = '#E6000000';
  static readonly OUTER_SCREEN_COVER_PROGRESS_GAP: number = 16;
  static readonly OUTER_SCREEN_PROGRESS_HEIGHT: number = 2.5;
  static readonly OUTER_SCREEN_PROGRESS_WIDTH_RATIO: number = 0.85;
  static readonly OUTER_SCREEN_PROGRESS_TOUCH_HEIGHT: number = 28;
  static readonly OUTER_SCREEN_PROGRESS_THUMB_SIZE: number = 10;
  static readonly OUTER_SCREEN_PROGRESS_TRACK_DARK: string = '#18FFFFFF';
  static readonly OUTER_SCREEN_PROGRESS_FILL_DARK: string = '#59FFFFFF';
  static readonly OUTER_SCREEN_PROGRESS_THUMB_DARK: string = '#B3FFFFFF';
  static readonly OUTER_SCREEN_PROGRESS_TRACK_LIGHT: string = '#1A3C3F4A';
  static readonly OUTER_SCREEN_PROGRESS_FILL_LIGHT: string = '#997B6BA8';
  static readonly OUTER_SCREEN_PROGRESS_THUMB_LIGHT: string = '#CC7B6BA8';
  static readonly OUTER_SCREEN_BG_GRADIENT_TOP_DARK: string = '#1A1B22';
  static readonly OUTER_SCREEN_BG_GRADIENT_BOTTOM_DARK: string = '#101116';
  static readonly OUTER_SCREEN_BEZEL_DARK: string = '#06070A';
  static readonly OUTER_SCREEN_BG_GRADIENT_TOP_LIGHT: string = '#F7F9FC';
  static readonly OUTER_SCREEN_BG_GRADIENT_BOTTOM_LIGHT: string = '#EEF2F7';
  static readonly OUTER_SCREEN_BEZEL_LIGHT: string = '#D8DCE3';

  /**
   * Pura X 外屏官方规格（bpta-purax-guide「屏幕规格信息」）：
   * 折叠态 980×980 px，326×326 vp；展开态内屏 1320×2120 px，440×707 vp。
   */
  static readonly PURAX_OUTER_SCREEN_EDGE_VP: number = 326;
  static readonly PURAX_OUTER_SCREEN_EDGE_PX: number = 980;
  static readonly PURAX_INNER_SCREEN_WIDTH_VP: number = 440;
  static readonly PURAX_INNER_SCREEN_HEIGHT_VP: number = 707;
  static readonly PURAX_INNER_SCREEN_WIDTH_PX: number = 1320;
  static readonly PURAX_INNER_SCREEN_HEIGHT_PX: number = 2120;
  /**
   * 外屏物理圆角：官方文档未给 vp 值，按外屏边长等比推导（约 11% 边长，4vp 对齐为 36vp）。
   * 真外屏由系统窗口裁剪，预览框按视口等比缩放该值。
   */
  static readonly PURAX_OUTER_SCREEN_CORNER_RADIUS_VP: number = 36;

  /** 内屏预览：方屏边长 = 宿主短边 × (外屏宽 vp / 内屏宽 vp)。 */
  static resolveOuterScreenPreviewViewportVp(hostMinEdgeVp: number): number {
    if (hostMinEdgeVp <= 0) {
      return 280;
    }
    return Math.floor(hostMinEdgeVp * UiTokens.PURAX_OUTER_SCREEN_EDGE_VP / UiTokens.PURAX_INNER_SCREEN_WIDTH_VP);
  }

  /** 预览框圆角随视口相对 326vp 外屏等比缩放。 */
  static resolveOuterScreenPreviewCornerRadiusVp(viewportEdgeVp: number): number {
    if (viewportEdgeVp <= 0) {
      return 16;
    }
    const scaled: number = Math.floor(viewportEdgeVp * UiTokens.PURAX_OUTER_SCREEN_CORNER_RADIUS_VP /
      UiTokens.PURAX_OUTER_SCREEN_EDGE_VP);
    return Math.max(12, scaled);
  }
}
