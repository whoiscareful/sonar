import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

@Component
export struct GlassSearchBar {
  @Prop keyword: string = '';
  @Prop placeholder: string = '搜索';
  @Prop topPadding: number = 0;
  @Prop sidePadding: number = UiTokens.PAGE_HORIZONTAL_PADDING;
  @Prop barHeight: number = UiTokens.LIBRARY_SEARCH_HEIGHT;
  @BuilderParam onKeywordChange: (value: string) => void;
  @BuilderParam onSubmit: () => void;

  build() {
    Row() {
      Row() {
        TextInput({ text: this.keyword, placeholder: this.placeholder })
          .width('100%')
          .height(this.barHeight)
          .borderRadius(this.barHeight / 2)
          .backgroundColor(Color.Transparent)
          .padding({ left: 18, right: 18 })
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          .placeholderColor(UiTokens.COLOR_TEXT_SECONDARY)
          .enterKeyType(EnterKeyType.Search)
          .caretColor(UiTokens.COLOR_PRIMARY)
          .onChange((value: string) => {
            if (this.onKeywordChange !== undefined) {
              this.onKeywordChange(value);
            }
          })
          .onSubmit((_enterKey: EnterKeyType) => {
            if (this.onSubmit !== undefined) {
              this.onSubmit();
            }
          })
      }
      .width('100%')
      .borderRadius(this.barHeight / 2)
      .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
      .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
      .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
    }
    .width('100%')
    .padding({
      left: this.sidePadding,
      right: this.sidePadding,
      top: this.topPadding
    })
  }
}
