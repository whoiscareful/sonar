import deviceInfo from '@ohos.deviceInfo';

export class NavigationPlatform {
  static supportsHdsNavigation(): boolean {
    return deviceInfo.distributionOSApiVersion >= 60100;
  }
}
