import { pasteboard } from '@kit.BasicServicesKit';
import { AuthStore } from '../auth/AuthStore';
import { AppTextArea } from '../components/forms/AppTextArea';
import { AppTextInput } from '../components/forms/AppTextInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { SecondaryButton } from '../components/buttons/SecondaryButton';
import { CardContainer } from '../components/layout/CardContainer';
import { ToastUtil } from '../common/ToastUtil';
import { ConfigCodecError, SonarConfigCodec } from '../settings/SonarConfigCodec';
import { UiTokens } from '../ui/tokens/UiTokens';

@Component
export struct ExportConfigPage {
  @State exportPassword: string = '';
  @State exportedBase64: string = '';
  @State isGenerating: boolean = false;
  @State errorMessage: string = '';
  @State hasRememberedInfo: boolean = false;

  aboutToAppear(): void {
    void this.checkRememberedInfo();
  }

  private async checkRememberedInfo(): Promise<void> {
    const info = await AuthStore.getInstance().getRememberedLoginInfo();
    this.hasRememberedInfo =
      info.remoteServerUrl.trim().length > 0 &&
      info.username.trim().length > 0 &&
      info.password.length > 0;
  }

  private async generateConfig(): Promise<void> {
    if (this.isGenerating) {
      return;
    }
    if (!this.hasRememberedInfo) {
      this.errorMessage = '请在我的 > 服务器完成登录';
      return;
    }
    this.isGenerating = true;
    this.errorMessage = '';
    try {
      const info = await AuthStore.getInstance().getRememberedLoginInfo();
      this.exportedBase64 = await SonarConfigCodec.exportConfig(info, this.exportPassword);
    } catch (err) {
      if (err instanceof ConfigCodecError) {
        this.errorMessage = err.message;
      } else {
        this.errorMessage = `导出失败: ${(err as Error).message}`;
      }
    } finally {
      this.isGenerating = false;
    }
  }

  private async copyToClipboard(): Promise<void> {
    if (this.exportedBase64.length === 0) {
      return;
    }
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.exportedBase64);
      await pasteboard.getSystemPasteboard().setData(pasteData);
      ToastUtil.show(this, '已复制到剪贴板，请妥善保管');
    } catch (_err) {
      ToastUtil.show(this, '复制失败');
    }
  }

  build() {
    CardContainer() {
      Column({ space: 10 }) {
        Text('导出服务器登录配置为 Base64，可在登录页「导入」Tab 恢复。')
          .fontSize(13)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .alignSelf(ItemAlign.Start)

        if (!this.hasRememberedInfo) {
          Text('请在我的 > 服务器完成登录')
            .fontSize(13)
            .fontColor(UiTokens.COLOR_ERROR)
            .alignSelf(ItemAlign.Start)
        }

        AppTextInput({
          text: this.exportPassword,
          placeholder: '配置密码 (可选，留空使用默认)',
          isPassword: true,
          onValueChange: (v: string) => {
            this.exportPassword = v;
          }
        })

        PrimaryButton({
          text: '生成配置',
          loading: this.isGenerating,
          isEnabled: this.hasRememberedInfo && !this.isGenerating,
          onPressed: () => {
            void this.generateConfig();
          }
        })

        if (this.exportedBase64.length > 0) {
          AppTextArea({
            text: this.exportedBase64,
            placeholder: '',
            areaHeight: 140,
            readOnly: true,
            onValueChange: (_v: string) => {
            }
          })

          SecondaryButton({
            text: '复制到剪贴板',
            onPressed: () => {
              void this.copyToClipboard();
            }
          })
            .alignSelf(ItemAlign.Start)

          Text('配置含登录密码，请勿分享给不可信的人')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .alignSelf(ItemAlign.Start)
        }

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor(UiTokens.COLOR_ERROR)
            .alignSelf(ItemAlign.Start)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
