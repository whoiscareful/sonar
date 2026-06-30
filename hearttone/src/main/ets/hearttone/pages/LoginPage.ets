import { LoginViewModel } from '../viewmodel/LoginViewModel';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppTextInput } from '../components/forms/AppTextInput';
import { AppTextArea } from '../components/forms/AppTextArea';
import { LoginModeSegment } from '../components/forms/LoginModeSegment';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { CardContainer } from '../components/layout/CardContainer';
import { HeartTonePageLayout } from '../components/layout/HeartTonePageLayout';
import { ImmersiveMaterialHelper } from '../ui/material/ImmersiveMaterialHelper';
import { GlassSurfaceHelper } from '../ui/material/GlassSurfaceHelper';
import {
  HeartTonePageLayoutOptions,
  HeartTonePageRole,
  HeartToneScrollMode
} from '../ui/layout/HeartTonePageLayoutOptions';
import { UiTokens } from '../ui/tokens/UiTokens';

const DOMAIN = 0x0000;
const TAG = 'HeartTone.LoginPage';
/** 服务器 Tab 四行输入 + 按钮高度，两 Tab 共用固定槽位避免切换抖动 */
const LOGIN_FORM_BODY_MIN_HEIGHT: number = 292;

@Component
export struct LoginPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State vm: LoginViewModel = new LoginViewModel();
  @State loginTabIndex: number = 0;

  private layoutOptions(): HeartTonePageLayoutOptions {
    return {
      role: HeartTonePageRole.STANDALONE,
      contentVariant: 'login',
      scrollMode: HeartToneScrollMode.SCROLL
    };
  }

  aboutToAppear(): void {
    ImmersiveMaterialHelper.probeAndCache();
    hilog.info(DOMAIN, TAG, 'LoginPage aboutToAppear');
    void this.vm.restoreRememberedInputs();
    try {
      hilog.info(DOMAIN, TAG, 'vm constructor returned ok, vm=%{public}o', typeof this.vm);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'vm access failed: %{public}s', (err as Error).message);
    }
  }

  private selectLoginTab(index: number): void {
    this.loginTabIndex = index;
    this.vm.errorMessage = '';
  }

  @Builder
  compositeUrlInput(
    protocol: string,
    host: string,
    port: string,
    hostPlaceholder: string,
    onProtocolToggle: () => void,
    onHostChange: (v: string) => void,
    onPortChange: (v: string) => void
  ) {
    Row() {
      Text(`${protocol}://`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(UiTokens.COLOR_PRIMARY)
        .padding({ left: 14, right: 6 })
        .height('100%')
        .textAlign(TextAlign.Center)
        .onClick(() => {
          onProtocolToggle();
        })

      TextInput({ text: host, placeholder: hostPlaceholder })
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .padding({ left: 0, right: 6 })
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .placeholderColor(UiTokens.COLOR_TEXT_SECONDARY)
        .type(InputType.Normal)
        .caretColor(UiTokens.COLOR_PRIMARY)
        .onChange((value: string) => {
          onHostChange(value);
        })

      Text(':')
        .fontSize(14)
        .fontColor(UiTokens.COLOR_TEXT_SECONDARY)

      TextInput({ text: port, placeholder: '端口' })
        .width(72)
        .height('100%')
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .padding({ left: 6, right: 14 })
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .placeholderColor(UiTokens.COLOR_TEXT_SECONDARY)
        .type(InputType.Number)
        .caretColor(UiTokens.COLOR_PRIMARY)
        .onChange((value: string) => {
          onPortChange(value);
        })
    }
    .width('100%')
    .height(46)
    .borderRadius(12)
    .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
    .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
    .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
    .margin({ bottom: 10 })
  }

  @LocalBuilder
  serverTabContent() {
    this.compositeUrlInput(
      this.vm.serverProtocol,
      this.vm.serverHost,
      this.vm.serverPort,
      'navidrome.example.com',
      () => {
        this.vm.serverProtocol = this.vm.serverProtocol === 'https' ? 'http' : 'https';
      },
      (v: string) => {
        this.vm.serverHost = v;
      },
      (v: string) => {
        this.vm.serverPort = v;
      }
    )

    this.compositeUrlInput(
      this.vm.localServerProtocol,
      this.vm.localServerHost,
      this.vm.localServerPort,
      '192.168.1.10 (可选)',
      () => {
        this.vm.localServerProtocol = this.vm.localServerProtocol === 'https' ? 'http' : 'https';
      },
      (v: string) => {
        this.vm.localServerHost = v;
      },
      (v: string) => {
        this.vm.localServerPort = v;
      }
    )

    AppTextInput({
      text: this.vm.username,
      placeholder: '用户名',
      onValueChange: (v: string) => {
        this.vm.username = v;
      }
    })
      .margin({ bottom: 10 })

    AppTextInput({
      text: this.vm.password,
      placeholder: '密码',
      isPassword: true,
      onValueChange: (v: string) => {
        this.vm.password = v;
      }
    })
      .margin({ bottom: 18 })

    PrimaryButton({
      text: '登 录',
      loading: this.vm.isLoading,
      isEnabled: !this.vm.isLoading,
      onPressed: () => {
        this.vm.submit(() => {
          AppStorage.setOrCreate<number>('rootTabIndex', 1);
          this.appPathStack.clear();
        });
      }
    })
  }

  @LocalBuilder
  importTabContent() {
    Text('粘贴导出的 Base64 配置')
      .fontSize(13)
      .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
      .alignSelf(ItemAlign.Start)
      .margin({ bottom: 10 })

    AppTextArea({
      text: this.vm.importBase64,
      placeholder: 'Base64 配置内容',
      areaHeight: 120,
      onValueChange: (v: string) => {
        this.vm.importBase64 = v;
      }
    })
      .margin({ bottom: 10 })

    AppTextInput({
      text: this.vm.importPassword,
      placeholder: '配置密码 (可选，留空使用默认)',
      isPassword: true,
      onValueChange: (v: string) => {
        this.vm.importPassword = v;
      }
    })
      .margin({ bottom: 18 })

    PrimaryButton({
      text: '导入并登录',
      loading: this.vm.isLoading,
      isEnabled: !this.vm.isLoading,
      onPressed: () => {
        this.vm.importAndLogin(
          () => {
            this.selectLoginTab(0);
          },
          () => {
            AppStorage.setOrCreate<number>('rootTabIndex', 1);
            this.appPathStack.clear();
          }
        );
      }
    })
  }

  @LocalBuilder
  buildLoginFormCard() {
    LoginModeSegment({
      selectedIndex: this.loginTabIndex,
      onSelect: (index: number) => {
        this.selectLoginTab(index);
      }
    })
      .margin({ bottom: 16 })

    Column() {
      if (this.loginTabIndex === 0) {
        this.serverTabContent()
      } else {
        this.importTabContent()
      }
    }
    .width('100%')
    .height(LOGIN_FORM_BODY_MIN_HEIGHT)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)

    if (this.vm.errorMessage.length > 0) {
      Text(this.vm.errorMessage)
        .fontSize(13)
        .fontColor(UiTokens.COLOR_ERROR)
        .margin({ top: 14 })
        .alignSelf(ItemAlign.Start)
    }
  }

  @LocalBuilder
  buildLoginBody() {
    Column() {
      Blank().height(48)
      Column() {
        Text('心音')
          .fontSize(48)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          .letterSpacing(2)
        Text('让自部署音乐，回到你的口袋')
          .fontSize(14)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .margin({ top: 8 })
      }
      .margin({ bottom: 24 })
      .alignItems(HorizontalAlign.Center)

      CardContainer() {
        this.buildLoginFormCard()
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    HeartTonePageLayout({
      options: this.layoutOptions(),
      content: this.buildLoginBody
    })
  }
}
