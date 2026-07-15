import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { CardContainer } from '../components/layout/CardContainer';
import { AppearanceUpdateResult, ProfileAppearanceStore } from '../settings/ProfileAppearanceStore';
import { UiTokens } from '../ui/tokens/UiTokens';

@Component
export struct PersonalizationSettingsPage {
  @StorageLink('profileAppearanceRevision') @Watch('onAppearanceChanged') profileAppearanceRevision: number = 0;
  @StorageLink('loggedInUser') loggedInUser: string = '';
  @State private avatarUri: string = '';
  @State private coverUri: string = '';
  @State private randomApiUrl: string = '';
  @State private avatarInputUrl: string = '';
  @State private coverInputUrl: string = '';
  @State private backgroundBlur: number = 0;
  @State private backgroundMask: number = 0.32;
  @State private imageSourceIndex: number = 0;
  @State private pageWidth: number = 360;
  @State private pageHeight: number = 720;
  @State private busy: boolean = false;
  private readonly appearanceStore: ProfileAppearanceStore = ProfileAppearanceStore.getInstance();

  aboutToAppear(): void {
    this.onAppearanceChanged();
  }

  private onAppearanceChanged(): void {
    this.avatarUri = this.appearanceStore.avatarUri();
    this.coverUri = this.appearanceStore.coverUri();
    this.randomApiUrl = this.appearanceStore.randomApiUrl();
    this.avatarInputUrl = this.avatarUri;
    this.coverInputUrl = this.coverUri;
    this.backgroundBlur = this.appearanceStore.backgroundBlur();
    this.backgroundMask = this.appearanceStore.backgroundMask();
  }

  private avatarText(): string {
    return this.loggedInUser.length > 0 ? this.loggedInUser.slice(0, 1).toUpperCase() : 'H';
  }

  private useForeignImageSource(): boolean {
    return this.imageSourceIndex === 1;
  }

  private imageSourceName(): string {
    return this.useForeignImageSource() ? '国外源 moe.jitsu.top' : '国内源 api.anosu.top';
  }

  private deviceBackgroundPlanText(): string {
    return this.appearanceStore.randomBackgroundDeviceDescription(this.pageWidth, this.pageHeight);
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
  }

  private async pickImage(avatar: boolean): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length === 0) {
        return;
      }
      const updated: AppearanceUpdateResult = avatar ?
        await this.appearanceStore.updateAvatar(result.photoUris[0]) :
        await this.appearanceStore.updateInterfaceBackground(result.photoUris[0]);
      this.onAppearanceChanged();
      this.showToast(avatar && updated.synced ? '已更新并同步到 Music Tag Web' : '已保存到本机');
    } catch (err) {
      this.showToast(`图片更新失败：${(err as Error).message}`);
    } finally {
      this.busy = false;
    }
  }

  private async saveRandomApi(): Promise<void> {
    try {
      await this.appearanceStore.setRandomApiUrl(this.randomApiUrl);
      this.showToast('随机图片 API 已保存');
    } catch (err) {
      this.showToast(`保存失败：${(err as Error).message}`);
    }
  }

  private async saveImageUrl(avatar: boolean): Promise<void> {
    const sourceUrl: string = avatar ? this.avatarInputUrl : this.coverInputUrl;
    if (sourceUrl.length === 0) {
      this.showToast('请先填写图片地址或 API 地址');
      return;
    }
    try {
      if (avatar) {
        await this.appearanceStore.updateAvatarUri(sourceUrl);
      } else {
        await this.appearanceStore.updateCoverUri(sourceUrl);
      }
      this.onAppearanceChanged();
      this.showToast('图片地址已应用');
    } catch (err) {
      this.showToast(`保存失败：${(err as Error).message}`);
    }
  }

  private async useRandomAvatar(): Promise<void> {
    this.avatarInputUrl = this.appearanceStore.randomAvatarUrlFromSource(this.useForeignImageSource());
    await this.saveImageUrl(true);
  }

  private async useRandomBackground(): Promise<void> {
    this.coverInputUrl =
      this.appearanceStore.randomBackgroundUrlForDevice(this.pageWidth, this.pageHeight, this.useForeignImageSource());
    await this.saveImageUrl(false);
  }

  private async saveBackgroundEffects(): Promise<void> {
    try {
      await this.appearanceStore.setBackgroundEffects(this.backgroundBlur, this.backgroundMask);
      this.showToast('背景效果已保存');
    } catch (err) {
      this.showToast(`保存失败：${(err as Error).message}`);
    }
  }

  @Builder
  private preview() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.coverUri.length > 0) {
        Image(this.coverUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(this.backgroundBlur)
          .opacity(0.72)
      }
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .opacity(this.backgroundMask)
      Column({ space: 12 }) {
        if (this.avatarUri.length > 0) {
          Image(this.avatarUri)
            .width(84)
            .height(84)
            .borderRadius(28)
            .objectFit(ImageFit.Cover)
        } else {
          Text(this.avatarText())
            .width(84)
            .height(84)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
            .textAlign(TextAlign.Center)
            .borderRadius(28)
            .backgroundColor(UiTokens.COLOR_ACTION_BG)
        }
        Text(this.loggedInUser.length > 0 ? this.loggedInUser : 'HeartTone')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
      }
    }
    .width('100%')
    .height(224)
    .borderRadius(24)
    .clip(true)
    .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
  }

  build() {
    Scroll() {
      Column({ space: UiTokens.SECTION_GAP }) {
        this.preview()
        CardContainer() {
          Column({ space: 14 }) {
            Text('个人信息外观')
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text('头像会保存在当前设备；配置了兼容 API 后可同步到 Music Tag Web。界面背景会应用到首页、音乐、我的和播放页。')
              .width('100%')
              .fontSize(12)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            Button('更换头像')
              .width('100%')
              .height(46)
              .fontColor(this.busy ? UiTokens.COLOR_TEXT_SECONDARY : UiTokens.COLOR_TEXT_ON_BRAND)
              .backgroundColor(this.busy ? UiTokens.COLOR_PRIMARY_DISABLED_BG : UiTokens.COLOR_ACTION_BG)
              .borderRadius(16)
              .enabled(!this.busy)
              .onClick(() => {
                void this.pickImage(true);
              })
            Button('更换界面背景')
              .width('100%')
              .height(46)
              .fontColor(this.busy ? UiTokens.COLOR_TEXT_SECONDARY : UiTokens.COLOR_TEXT_ON_BRAND)
              .backgroundColor(this.busy ? UiTokens.COLOR_PRIMARY_DISABLED_BG : UiTokens.COLOR_ACTION_BG)
              .borderRadius(16)
              .enabled(!this.busy)
              .onClick(() => {
                void this.pickImage(false);
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        CardContainer() {
          Column({ space: 13 }) {
            Text('随机图片 API')
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text(`当前图源：${this.imageSourceName()}。头像不再传不受支持的 size=square，背景仍按设备只传 ${this.deviceBackgroundPlanText()}。图片地址支持普通 URL 和 302 API 地址。`)
              .width('100%')
              .fontSize(12)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            Row({ space: 10 }) {
              Button('国内源')
                .layoutWeight(1)
                .height(38)
                .fontSize(13)
                .fontColor(this.imageSourceIndex === 0 ? UiTokens.COLOR_TEXT_ON_BRAND : UiTokens.COLOR_TEXT_SECONDARY)
                .backgroundColor(this.imageSourceIndex === 0 ? UiTokens.COLOR_ACTION_BG : UiTokens.COLOR_PRIMARY_SOFT_BG)
                .borderRadius(14)
                .onClick(() => {
                  this.imageSourceIndex = 0;
                  this.randomApiUrl = this.appearanceStore.defaultAvatarApiUrl();
                })
              Button('国外源')
                .layoutWeight(1)
                .height(38)
                .fontSize(13)
                .fontColor(this.imageSourceIndex === 1 ? UiTokens.COLOR_TEXT_ON_BRAND : UiTokens.COLOR_TEXT_SECONDARY)
                .backgroundColor(this.imageSourceIndex === 1 ? UiTokens.COLOR_ACTION_BG : UiTokens.COLOR_PRIMARY_SOFT_BG)
                .borderRadius(14)
                .onClick(() => {
                  this.imageSourceIndex = 1;
                  this.randomApiUrl = this.appearanceStore.foreignImageApiUrl();
                })
            }
            .width('100%')
            TextInput({ text: this.randomApiUrl, placeholder: this.appearanceStore.defaultAvatarApiUrl() })
              .width('100%')
              .height(44)
              .fontSize(13)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
              .borderRadius(14)
              .onChange((value: string) => {
                this.randomApiUrl = value;
              })
            Button('保存随机头像 API')
              .width('100%')
              .height(42)
              .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
              .backgroundColor(UiTokens.COLOR_ACTION_BG)
              .borderRadius(14)
              .onClick(() => {
                void this.saveRandomApi();
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        CardContainer() {
          Column({ space: 13 }) {
            Text('头像地址')
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            TextInput({ text: this.avatarInputUrl, placeholder: this.appearanceStore.defaultAvatarApiUrl() })
              .width('100%')
              .height(44)
              .fontSize(13)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
              .borderRadius(14)
              .onChange((value: string) => {
                this.avatarInputUrl = value;
              })
            Row({ space: 10 }) {
              Button('使用随机头像')
                .layoutWeight(1)
                .height(42)
                .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
                .backgroundColor(UiTokens.COLOR_ACTION_BG)
                .borderRadius(14)
                .onClick(() => {
                  void this.useRandomAvatar();
                })
              Button('应用地址')
                .layoutWeight(1)
                .height(42)
                .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
                .backgroundColor(UiTokens.COLOR_ACTION_BG)
                .borderRadius(14)
                .onClick(() => {
                  void this.saveImageUrl(true);
                })
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        CardContainer() {
          Column({ space: 13 }) {
            Text('全局界面背景地址')
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text(`自动匹配：${this.deviceBackgroundPlanText()}。横屏/大屏使用 pc，竖屏使用 mp；请求只携带 sort 参数。`)
              .width('100%')
              .fontSize(12)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            TextInput({ text: this.coverInputUrl, placeholder: this.appearanceStore.defaultBackgroundApiUrl() })
              .width('100%')
              .height(44)
              .fontSize(13)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
              .borderRadius(14)
              .onChange((value: string) => {
                this.coverInputUrl = value;
              })
            Row({ space: 10 }) {
              Button('按设备随机背景')
                .layoutWeight(1)
                .height(42)
                .fontSize(13)
                .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
                .backgroundColor(UiTokens.COLOR_ACTION_BG)
                .borderRadius(14)
                .onClick(() => {
                  void this.useRandomBackground();
                })
              Button('应用地址')
                .layoutWeight(1)
                .height(42)
                .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
                .backgroundColor(UiTokens.COLOR_ACTION_BG)
                .borderRadius(14)
                .onClick(() => {
                  void this.saveImageUrl(false);
                })
            }
            .width('100%')
            Text(`模糊 ${Math.round(this.backgroundBlur)} · 遮罩 ${Math.round(this.backgroundMask * 100)}%`)
              .fontSize(12)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            Slider({ value: this.backgroundBlur, min: 0, max: 40, step: 1 })
              .width('100%')
              .blockColor(UiTokens.COLOR_ACTION_BG)
              .selectedColor(UiTokens.COLOR_ACTION_BG)
              .trackColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
              .onChange((value: number) => {
                this.backgroundBlur = value;
              })
            Slider({ value: this.backgroundMask * 100, min: 0, max: 78, step: 1 })
              .width('100%')
              .blockColor(UiTokens.COLOR_ACTION_BG)
              .selectedColor(UiTokens.COLOR_ACTION_BG)
              .trackColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
              .onChange((value: number) => {
                this.backgroundMask = value / 100;
              })
            Button('保存背景效果')
              .width('100%')
              .height(42)
              .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
              .backgroundColor(UiTokens.COLOR_ACTION_BG)
              .borderRadius(14)
              .onClick(() => {
                void this.saveBackgroundEffects();
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      if (newValue.width !== undefined) {
        this.pageWidth = Math.floor(Number(newValue.width));
      }
      if (newValue.height !== undefined) {
        this.pageHeight = Math.floor(Number(newValue.height));
      }
    })
  }
}
