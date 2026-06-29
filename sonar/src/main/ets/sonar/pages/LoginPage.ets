import { LoginViewModel } from '../viewmodel/LoginViewModel';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppTextInput } from '../components/forms/AppTextInput';
import { AppTextArea } from '../components/forms/AppTextArea';
import { LoginModeSegment } from '../components/forms/LoginModeSegment';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { CardContainer } from '../components/layout/CardContainer';
import { SonarPageLayout } from '../components/layout/SonarPageLayout';
import { ImmersiveMaterialHelper } from '../ui/material/ImmersiveMaterialHelper';
import {
  SonarPageLayoutOptions,
  SonarPageRole,
  SonarScrollMode
} from '../ui/layout/SonarPageLayoutOptions';
import { UiTokens } from '../ui/tokens/UiTokens';

const DOMAIN = 0x0000;
const TAG = 'Sonar.LoginPage';
/** 服务器 Tab 四行输入 + 按钮高度，两 Tab 共用固定槽位避免切换抖动 */
const LOGIN_FORM_BODY_MIN_HEIGHT: number = 292;

@Component
export struct LoginPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State vm: LoginViewModel = new LoginViewModel();
  @State loginTabIndex: number = 0;

  private layoutOptions(): SonarPageLayoutOptions {
    return {
      role: SonarPageRole.STANDALONE,
      contentVariant: 'login',
      scrollMode: SonarScrollMode.SCROLL
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

  @LocalBuilder
  serverTabContent() {
    AppTextInput({
      text: this.vm.serverUrl,
      placeholder: '服务器地址 (例: https://navidrome.example.com)',
      onValueChange: (v: string) => {
        this.vm.serverUrl = v;
      }
    })
      .margin({ bottom: 10 })

    AppTextInput({
      text: this.vm.localServerUrl,
      placeholder: '本地 URL (可选，例: http://192.168.1.10:4533)',
      onValueChange: (v: string) => {
        this.vm.localServerUrl = v;
      }
    })
      .margin({ bottom: 10 })

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
        Text('Sonar')
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
    SonarPageLayout({
      options: this.layoutOptions(),
      content: this.buildLoginBody
    })
  }
}
