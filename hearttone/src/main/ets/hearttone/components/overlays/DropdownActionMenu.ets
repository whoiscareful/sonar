import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

export interface DropdownActionItem {
  id: string;
  label: string;
  backgroundColor: ResourceColor;
  fontColor: ResourceColor;
}

@Component
export struct DropdownActionMenu {
  @Prop isVisible: boolean = false;
  @Prop title: string = '';
  @Prop actions: DropdownActionItem[] = [];
  @BuilderParam closeMenu: () => void;
  @BuilderParam selectAction: (id: string) => void;

  build() {
    if (this.isVisible) {
      Stack() {
        Column() {
        }
        .width('100%')
        .height('100%')
        .backgroundColor(UiTokens.COLOR_OVERLAY_SCRIM)
        .onClick(() => {
          if (this.closeMenu !== undefined) {
            this.closeMenu();
          }
        })

        Column({ space: 10 }) {
          Text(this.title)
            .fontSize(13)
            .fontColor(UiTokens.COLOR_DROPDOWN_TITLE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          ForEach(this.actions, (item: DropdownActionItem) => {
            Button(item.label)
              .width('100%')
              .height(34)
              .fontSize(13)
              .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
              .backgroundColor(item.backgroundColor)
              .fontColor(item.fontColor)
              .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
              .borderRadius(10)
              .onClick(() => {
                if (this.selectAction !== undefined) {
                  this.selectAction(item.id);
                }
              })
          }, (item: DropdownActionItem) => item.id)
        }
        .width(188)
        .padding(12)
        .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
        .backgroundColor(UiTokens.COLOR_DROPDOWN_PANEL_BG)
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
        .margin({ right: 18, bottom: 26 })
        .align(Alignment.BottomEnd)
      }
      .width('100%')
      .height('100%')
    } else {
      Column() {
      }
      .width(0)
      .height(0)
    }
  }
}
