import { SonicApiEntryModule } from '../../view/SonicApiEntryModule';
import { CardContainer } from '../layout/CardContainer';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { PrimaryButton } from '../buttons/PrimaryButton';
import { MusicTagWebHealth, MusicTagWebStats } from '../../enhanced/MusicTagWebOpenApi';
import { MusicTagWebOpenApiClient } from '../../enhanced/MusicTagWebOpenApiClient';
import { OpenApiCredentialStore } from '../../enhanced/OpenApiCredentialStore';

@Component
export struct ServerSettingsContent {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInServer') loggedInServer: string = '';
  @StorageLink('loggedInUser') loggedInUser: string = '';
  @StorageLink('loggedInEndpoint') loggedInEndpoint: string = 'remote';
  @StorageLink('networkType') networkType: string = 'none';
  @State private openApiTokenInput: string = '';
  @State private openApiStatus: string = '未验证';
  @State private openApiBusy: boolean = false;
  @StorageLink('hasOpenApiToken') hasOpenApiToken: boolean = false;
  private readonly openApiClient: MusicTagWebOpenApiClient = MusicTagWebOpenApiClient.getInstance();

  aboutToAppear(): void {
    void this.loadTokenState();
  }

  private async loadTokenState(): Promise<void> {
    const token: string = await OpenApiCredentialStore.getToken();
    this.hasOpenApiToken = token.length > 0;
    // 不把掩码当作输入框真实值，避免粘贴新 Token 时保存成“******** + Token”。
    this.openApiTokenInput = '';
    this.openApiStatus = token.length > 0 ? 'Token 已保存' : '未配置 Token';
  }

  private describeNetworkType(): string {
    switch (this.networkType) {
      case 'wifi':
        return 'WIFI';
      case 'cellular':
        return '蜂窝移动网络';
      case 'none':
        return '无网络';
      default:
        return '其他网络';
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 1600 });
    } catch (_err) {
    }
  }

  private async verifyAndSaveOpenApiToken(): Promise<void> {
    if (this.openApiBusy || !this.isLoggedIn) {
      return;
    }
    const token: string = this.openApiTokenInput.trim();
    if (token.length === 0) {
      this.showToast(this.hasOpenApiToken ? '请输入新 Token 以替换' : '请输入 Token');
      return;
    }
    this.openApiBusy = true;
    this.openApiStatus = '正在直接验证输入的 Token…';
    const normalized: string = OpenApiCredentialStore.normalizeToken(token);
    try {
      const stats: MusicTagWebStats = await this.openApiClient.verifyToken(normalized, this.loggedInUser,
        'album_count,track_count,artist_count,song_size,song_duration,now_playing');
      await OpenApiCredentialStore.saveToken(normalized);
      const stored: string = await OpenApiCredentialStore.getToken();
      if (stored !== normalized) {
        throw new Error('服务器验证成功，但安全存储读回不一致');
      }
      const fingerprint: string = await OpenApiCredentialStore.fingerprint(stored);
      this.hasOpenApiToken = true;
      this.openApiStatus = `验证并保存成功 · ${fingerprint} · 专辑 ${stats.albumCount ?? '-'}`;
      this.openApiTokenInput = '';
      this.showToast('Token 验证成功并已安全保存');
    } catch (err) {
      const fingerprint: string = await OpenApiCredentialStore.fingerprint(normalized);
      this.openApiStatus = `验证或保存失败 · ${fingerprint}：${(err as Error).message}`;
      // 密码输入框无法直观看出是否追加了旧内容，失败后清空以防再次拼接。
      this.openApiTokenInput = '';
    } finally {
      this.openApiBusy = false;
    }
  }

  private async clearOpenApiToken(): Promise<void> {
    await OpenApiCredentialStore.clearToken();
    this.hasOpenApiToken = false;
    this.openApiTokenInput = '';
    this.openApiStatus = '未配置 Token';
    this.showToast('开放 API Token 已清除');
  }

  private async verifyOpenApi(): Promise<void> {
    if (this.openApiBusy || !this.isLoggedIn || !this.hasOpenApiToken) {
      return;
    }
    this.openApiBusy = true;
    try {
      const health: MusicTagWebHealth = await this.openApiClient.health();
      if (!health.healthy) {
        this.openApiStatus = `健康检查失败：${health.message}`;
        return;
      }
      const stats: MusicTagWebStats = await this.openApiClient.stats(this.loggedInUser,
        'album_count,track_count,artist_count,song_size,song_duration,now_playing');
      const token: string = await OpenApiCredentialStore.getToken();
      const fingerprint: string = await OpenApiCredentialStore.fingerprint(token);
      this.openApiStatus = `已保存 Token 正常 · ${fingerprint} · 专辑 ${stats.albumCount ?? '-'} · 歌曲 ${stats.trackCount ?? '-'}`;
    } catch (err) {
      this.openApiStatus = `验证失败：${(err as Error).message}`;
    } finally {
      this.openApiBusy = false;
    }
  }

  @LocalBuilder
  buildConnectionStatusCard() {
    Column({ space: 8 }) {
      Text('连接状态')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
      Text(this.isLoggedIn ? '已登录服务器' : '未登录')
        .fontSize(13)
        .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
      if (this.isLoggedIn) {
        Text(`${this.loggedInServer} · ${this.loggedInEndpoint === 'local' ? '本地' : '远程'}`)
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      Text(`当前网络：${this.describeNetworkType()}`)
        .fontSize(12)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: UiTokens.SECTION_GAP }) {
      SonicApiEntryModule()

      CardContainer() {
        this.buildConnectionStatusCard()
      }

      CardContainer() {
        Column({ space: 10 }) {
          Text('服务器配置')
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text('可配置局域网与远程地址。连接时优先使用局域网，无法访问时自动回退到远程服务器。')
            .width('100%')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          PrimaryButton({
            text: this.isLoggedIn ? '修改服务器配置' : '添加服务器',
            isEnabled: true,
            onPressed: () => {
              this.appPathStack.pushPathByName('LoginPage', null);
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      CardContainer() {
        Column({ space: 10 }) {
          Text('Music Tag Web 开放 API')
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text('用于音乐统计、歌词读取/保存和元数据详情。请填写 Music Tag Web API 管理页面生成的 Bearer Token；它与 Subsonic 播放登录相互独立。')
            .width('100%')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          TextInput({
            text: this.openApiTokenInput,
            placeholder: this.hasOpenApiToken ? '已保存；输入新 Token 可替换' : 'Bearer Token'
          })
            .width('100%')
            .height(44)
            .fontSize(13)
            .type(InputType.Password)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .borderRadius(14)
            .onChange((value: string) => {
              this.openApiTokenInput = value;
            })
          Text(this.openApiStatus)
            .width('100%')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          Row({ space: 10 }) {
            Button(this.openApiBusy ? '处理中' : '验证并保存')
              .layoutWeight(1)
              .height(42)
              .fontColor(this.openApiBusy || !this.isLoggedIn || this.openApiTokenInput.trim().length === 0 ?
                UiTokens.COLOR_TEXT_SECONDARY : UiTokens.COLOR_TEXT_ON_BRAND)
              .backgroundColor(this.openApiBusy || !this.isLoggedIn || this.openApiTokenInput.trim().length === 0 ?
                UiTokens.COLOR_PRIMARY_DISABLED_BG : UiTokens.COLOR_ACTION_BG)
              .borderRadius(14)
              .enabled(!this.openApiBusy && this.isLoggedIn && this.openApiTokenInput.trim().length > 0)
              .onClick(() => {
                void this.verifyAndSaveOpenApiToken();
              })
            Button(this.openApiBusy ? '验证中' : '验证已保存')
              .layoutWeight(1)
              .height(42)
              .fontColor(!this.openApiBusy && this.isLoggedIn && this.hasOpenApiToken ?
                UiTokens.COLOR_TEXT_ON_BRAND : UiTokens.COLOR_TEXT_SECONDARY)
              .backgroundColor(!this.openApiBusy && this.isLoggedIn && this.hasOpenApiToken ?
                UiTokens.COLOR_ACTION_BG : UiTokens.COLOR_PRIMARY_DISABLED_BG)
              .borderRadius(14)
              .enabled(!this.openApiBusy && this.isLoggedIn && this.hasOpenApiToken)
              .onClick(() => {
                void this.verifyOpenApi();
              })
          }
          .width('100%')
          Button('清除 Token')
            .width('100%')
            .height(42)
            .fontColor(this.hasOpenApiToken && !this.openApiBusy ?
              UiTokens.COLOR_TEXT_ON_BRAND : UiTokens.COLOR_TEXT_SECONDARY)
            .backgroundColor(this.hasOpenApiToken && !this.openApiBusy ?
              UiTokens.COLOR_ACTION_BG : UiTokens.COLOR_PRIMARY_DISABLED_BG)
            .borderRadius(14)
            .enabled(this.hasOpenApiToken && !this.openApiBusy)
            .onClick(() => {
              void this.clearOpenApiToken();
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
  }
}
