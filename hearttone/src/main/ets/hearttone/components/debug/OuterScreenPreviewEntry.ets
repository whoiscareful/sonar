import { CardContainer } from '../layout/CardContainer';
import { ScreenProfileStore } from '../../ui/adaptation/ScreenProfileStore';
import { UiTokens } from '../../ui/tokens/UiTokens';

/** 开发自测：一键进入外屏封面播放器 UI（不依赖外屏白名单） */
@Component
export struct OuterScreenPreviewEntry {
  @StorageLink('outerScreenPreview') outerScreenPreview: boolean = false;

  build() {
    CardContainer() {
      Column({ space: 8 }) {
        Text('外屏 UI 预览')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text('预览外屏播放器')
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        Button(this.outerScreenPreview ? '退出外屏预览' : '进入外屏预览')
          .width('100%')
          .height(40)
          .fontSize(14)
          .backgroundColor(this.outerScreenPreview ?
            UiTokens.COLOR_WARNING_SOFT_BG : UiTokens.COLOR_PRIMARY_SOFT_BG)
          .fontColor(this.outerScreenPreview ? UiTokens.COLOR_WARNING : UiTokens.COLOR_PRIMARY)
          .onClick(() => {
            const nextEnabled: boolean = !this.outerScreenPreview;
            ScreenProfileStore.setPreviewEnabled(nextEnabled);
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
