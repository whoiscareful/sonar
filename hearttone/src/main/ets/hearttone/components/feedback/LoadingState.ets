import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct LoadingState {
  @Prop message: string = '加载中…';

  build() {
    Column() {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(UiTokens.COLOR_PRIMARY)
      Text(this.message)
        .fontSize(13)
        .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        .margin({ top: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
