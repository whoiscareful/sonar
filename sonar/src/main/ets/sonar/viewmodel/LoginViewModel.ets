import { SubsonicApiError } from '../api/SubsonicTypes';
import { SubsonicApi } from '../network/api/SubsonicApi';
import { SubsonicUrlUtil } from '../network/api/SubsonicUrlUtil';
import { EndpointRouter } from '../network/routing/EndpointRouter';
import { AuthStore, SavedAuth } from '../auth/AuthStore';
import { AuthSession } from '../auth/AuthSession';
import { ConfigCodecError, SonarConfigCodec } from '../settings/SonarConfigCodec';

@Observed
export class LoginViewModel {
  serverUrl: string = '';
  localServerUrl: string = '';
  username: string = '';
  password: string = '';
  importBase64: string = '';
  importPassword: string = '';
  isLoading: boolean = false;
  errorMessage: string = '';
  private rememberedLoaded: boolean = false;

  private static describeError(err: SubsonicApiError): string {
    switch (err.code) {
      case -2:
        return err.message;
      case 0:
        return '无法连接服务器，请检查地址与网络';
      case 10:
        return '请求参数不完整或格式错误 (code 10)';
      case 40:
        return '用户名或密码错误 (code 40)';
      case 41:
        return '该账户不支持 token 登录，请改用支持的账号 (code 41)';
      case 50:
        return '当前账户没有执行该操作的权限 (code 50)';
      default:
        return `服务器错误 (${err.code}): ${err.message}`;
    }
  }

  async restoreRememberedInputs(): Promise<void> {
    if (this.rememberedLoaded) {
      return;
    }
    const info = await AuthStore.getInstance().getRememberedLoginInfo();
    if (this.serverUrl.length === 0) {
      this.serverUrl = info.remoteServerUrl;
    }
    if (this.localServerUrl.length === 0) {
      this.localServerUrl = info.localServerUrl;
    }
    if (this.username.length === 0) {
      this.username = info.username;
    }
    if (this.password.length === 0) {
      this.password = info.password;
    }
    this.rememberedLoaded = true;
  }

  async submit(onSuccess: () => void): Promise<void> {
    if (this.isLoading) {
      return;
    }
    const serverUrlInput: string = this.serverUrl.trim();
    const localServerUrlInput: string = this.localServerUrl.trim();
    const username: string = this.username.trim();
    const password: string = this.password;

    if (serverUrlInput.length === 0) {
      this.errorMessage = '请输入服务器地址';
      return;
    }
    if (username.length === 0) {
      this.errorMessage = '请输入用户名';
      return;
    }
    if (password.length === 0) {
      this.errorMessage = '请输入密码';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    try {
      const serverUrl: string = SubsonicUrlUtil.normalizeServerUrl(serverUrlInput);
      const localServerUrl: string | undefined = localServerUrlInput.length > 0 ?
        SubsonicUrlUtil.normalizeServerUrl(localServerUrlInput) : undefined;
      const loginAuth: SavedAuth =
        await SubsonicApi.buildLoginAuth(serverUrl, localServerUrl, username, password);
      await EndpointRouter.validateRemoteReachable(loginAuth);
      loginAuth.activeEndpoint = 'remote';
      const authStore: AuthStore = AuthStore.getInstance();
      await authStore.save(loginAuth);
      await authStore.rememberLoginInfo({
        remoteServerUrl: serverUrl,
        localServerUrl: localServerUrl ?? '',
        username,
        password
      });
      await AuthSession.signIn(loginAuth);
      onSuccess();
    } catch (err) {
      if (err instanceof SubsonicApiError) {
        this.errorMessage = LoginViewModel.describeError(err);
      } else {
        this.errorMessage = `网络错误: ${(err as Error).message}`;
      }
    } finally {
      this.isLoading = false;
    }
  }

  async importAndLogin(onTabSwitch: () => void, onSuccess: () => void): Promise<void> {
    if (this.isLoading) {
      return;
    }
    const base64Input: string = this.importBase64.trim();
    if (base64Input.length === 0) {
      this.errorMessage = '请输入配置内容';
      return;
    }
    this.isLoading = true;
    this.errorMessage = '';
    try {
      const payload = await SonarConfigCodec.importConfig(base64Input, this.importPassword);
      this.serverUrl = payload.remoteServerUrl;
      this.localServerUrl = payload.localServerUrl;
      this.username = payload.username;
      this.password = payload.password;
      onTabSwitch();
      this.isLoading = false;
      await this.submit(onSuccess);
    } catch (err) {
      if (err instanceof ConfigCodecError) {
        this.errorMessage = err.message;
      } else if (err instanceof SubsonicApiError) {
        this.errorMessage = LoginViewModel.describeError(err);
      } else {
        this.errorMessage = `导入失败: ${(err as Error).message}`;
      }
    } finally {
      this.isLoading = false;
    }
  }
}
