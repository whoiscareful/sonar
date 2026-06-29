import { connection } from '@kit.NetworkKit';
import { wifiManager } from '@kit.ConnectivityKit';
import { Logger } from './Logger';

export type NetworkType = 'wifi' | 'cellular' | 'none' | 'other';

/**
 * 网络状态检测工具。
 * 用于「非 WIFI 直接走远程、跳过本地探测」的门控，
 * 同时为后续缓存 / 听歌自动下载的流量提示预留接口。
 */
export class NetworkStatus {
  private static cachedWifiSsid: string = '';

  static setCachedWifiSsid(ssid: string): void {
    NetworkStatus.cachedWifiSsid = ssid;
  }

  static refreshCachedWifiSsid(): void {
    if (!NetworkStatus.isOnWifi()) {
      NetworkStatus.cachedWifiSsid = '';
      return;
    }
    try {
      if (!wifiManager.isWifiActive()) {
        NetworkStatus.cachedWifiSsid = '';
        return;
      }
      wifiManager.getLinkedInfo().then((linkedInfo) => {
        NetworkStatus.cachedWifiSsid = NetworkStatus.normalizeSsid(linkedInfo.ssid);
      }).catch((err: Error) => {
        Logger.warn('NetworkStatus', `refreshCachedWifiSsid failed: ${err.message}`);
      });
    } catch (err) {
      Logger.warn('NetworkStatus', `refreshCachedWifiSsid failed: ${(err as Error).message}`);
    }
  }
  private static readCapabilities(): connection.NetCapabilities | null {
    try {
      if (!connection.hasDefaultNetSync()) {
        return null;
      }
      const netHandle: connection.NetHandle = connection.getDefaultNetSync();
      return connection.getNetCapabilitiesSync(netHandle);
    } catch (err) {
      Logger.warn('NetworkStatus', `readCapabilities failed: ${(err as Error).message}`);
      return null;
    }
  }

  static getNetworkType(): NetworkType {
    const caps: connection.NetCapabilities | null = NetworkStatus.readCapabilities();
    if (caps === null) {
      return 'none';
    }
    const bearerTypes: connection.NetBearType[] = caps.bearerTypes ?? [];
    if (bearerTypes.includes(connection.NetBearType.BEARER_WIFI)) {
      return 'wifi';
    }
    if (bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR)) {
      return 'cellular';
    }
    return 'other';
  }

  static isOnWifi(): boolean {
    return NetworkStatus.getNetworkType() === 'wifi';
  }

  static getWifiSsid(): string {
    if (!NetworkStatus.isOnWifi()) {
      return '';
    }
    if (NetworkStatus.cachedWifiSsid.length > 0) {
      return NetworkStatus.cachedWifiSsid;
    }
    NetworkStatus.refreshCachedWifiSsid();
    return NetworkStatus.cachedWifiSsid;
  }

  private static normalizeSsid(raw: string): string {
    if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  /**
   * 是否为计费网络（蜂窝或被系统标记为计费的网络）。
   * 预留给缓存 / 自动下载的流量提示。
   */
  static isMetered(): boolean {
    const caps: connection.NetCapabilities | null = NetworkStatus.readCapabilities();
    if (caps === null) {
      return false;
    }
    const netCaps: connection.NetCap[] = caps.networkCap ?? [];
    if (netCaps.includes(connection.NetCap.NET_CAPABILITY_NOT_METERED)) {
      return false;
    }
    const bearerTypes: connection.NetBearType[] = caps.bearerTypes ?? [];
    return bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR);
  }
}
