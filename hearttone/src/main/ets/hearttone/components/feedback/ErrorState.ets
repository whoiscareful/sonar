import { PrimaryButton } from '../buttons/PrimaryButton';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct ErrorState {
  @Prop message: string = '加载失败';
  @Prop retryText: string = '重试';
  @BuilderParam onRetryPress: () => void;

  build() {
    Column() {
      Text('⚠ ' + this.message)
        .fontSize(14)
        .fontColor(UiTokens.COLOR_DANGER)
      Column() {
        PrimaryButton({
          text: this.retryText,
          onPressed: () => {
            if (this.onRetryPress !== undefined) {
              this.onRetryPress();
            }
          }
        })
      }
      .width(180)
      .margin({ top: 14 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
