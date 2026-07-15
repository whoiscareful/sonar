import { ProfileAppearanceStore } from '../../settings/ProfileAppearanceStore';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct GlobalPageBackground {
  @Prop showImage: boolean = true;
  @StorageLink('profileAppearanceRevision') profileAppearanceRevision: number = 0;
  private readonly appearanceStore: ProfileAppearanceStore = ProfileAppearanceStore.getInstance();

  private backgroundUri(): string {
    return this.appearanceStore.coverUri();
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
        })

      if (this.showImage && this.backgroundUri().length > 0) {
        Image(this.backgroundUri())
          .id(`global-background-${this.profileAppearanceRevision}`)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(this.appearanceStore.backgroundBlur())
          .opacity(0.82)
      }

      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0.08], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
        })
        .opacity(0.58)

      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .opacity(this.appearanceStore.backgroundMask())
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}
