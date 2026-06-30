import { TagButtonMenuItem } from './TagButton';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct MoreMenuIconButton {
  @Prop menuItems: TagButtonMenuItem[] = [];
  /** 封面图上的半透明底；列表行内为 false */
  @Prop useDarkOverlay: boolean = false;

  private iconFillColor(): ResourceColor {
    if (this.useDarkOverlay) {
      return '#FFFFFF';
    }
    return UiTokens.COLOR_TEXT_PRIMARY;
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Image($r('app.media.ic_more_vert'))
        .width(20)
        .height(20)
        .objectFit(ImageFit.Contain)
        .fillColor(this.iconFillColor())
    }
    .width(32)
    .height(32)
    .backgroundColor(this.useDarkOverlay ? '#66000000' : Color.Transparent)
    .hitTestBehavior(HitTestMode.Block)
    .accessibilityText('更多操作')
    .responseRegion({ width: 40, height: 40 })
    .bindMenu(this.menuItems)
  }
}
