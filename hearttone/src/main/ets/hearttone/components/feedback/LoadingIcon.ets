import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct LoadingIcon {
  @Prop iconSize: number = 24;
  @Prop color: ResourceColor = UiTokens.COLOR_TEXT_ON_BRAND;

  build() {
    Image($r('app.media.ic_loading'))
      .width(this.iconSize)
      .height(this.iconSize)
      .fillColor(this.color)
      .objectFit(ImageFit.Contain)
  }
}
