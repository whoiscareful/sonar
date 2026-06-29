import { connection } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import { AuthStore, EndpointType, SavedAuth } from '../../auth/AuthStore';
import { Logger } from '../../common/Logger';
import { NetworkStatus } from '../../common/NetworkStatus';
import { AuthContext } from '../auth/AuthContext';
import { HttpTransport } from '../transport/HttpTransport';
import { EndpointChangeEvent, EndpointChangeListener, SwitchReason } from './EndpointTypes';
import { WifiTrustCache } from './WifiTrustCache';

const WIFI_TRIGGER_DEBOUNCE_MS: number = 5000;
const UNKNOWN_PROBE_INTERVAL_MS: number = 10_000;
const UNKNOWN_PROBE_MAX_ATTEMPTS: number = 3;
const TRUSTED_PROBE_INTERVAL_MS: number = 3000;
const TRUSTED_PROBE_MAX_ATTEMPTS: number = 5;

export class EndpointRouter {
  private static listeners: EndpointChangeListener[] = [];
  private static netConnection = connection.createNetConnection();
  private static readonly netRegisterCallback: () => void = () => {};
  private static lastWifiTriggerMs: number = 0;
  private static lastNetworkType: string = 'none';
  private static isProbingLocal: boolean = false;
  private static probeSessionStopped: boolean = false;
  private static probeTimerId: number | null = null;
  private static probeAttempt: number = 0;
  private static started: boolean = false;

  static getActiveEndpoint(): EndpointType {
    return AuthStore.getInstance().getActiveEndpoint();
  }

  static isLocalBoostActive(): boolean {
    return EndpointRouter.getActiveEndpoint() === 'local';
  }

  static subscribe(listener: EndpointChangeListener): () => void {
    EndpointRouter.listeners.push(listener);
    return (): void => {
      const idx: number = EndpointRouter.listeners.indexOf(listener);
      if (idx >= 0) {
        EndpointRouter.listeners.splice(idx, 1);
      }
    };
  }

  static async init(context: common.Context): Promise<void> {
    await WifiTrustCache.init(context);
  }

  static start(): void {
    if (EndpointRouter.started) {
      return;
    }
    EndpointRouter.started = true;
    EndpointRouter.lastNetworkType = NetworkStatus.getNetworkType();
    NetworkStatus.refreshCachedWifiSsid();
    EndpointRouter.netConnection.on('netCapabilitiesChange', EndpointRouter.onNetCapabilitiesChange);
    EndpointRouter.netConnection.register(EndpointRouter.netRegisterCallback);
    Logger.info('EndpointRouter', 'network listener started');
  }

  static stop(): void {
    EndpointRouter.stopProbeSession();
    if (!EndpointRouter.started) {
      return;
    }
    EndpointRouter.netConnection.unregister(EndpointRouter.netRegisterCallback);
    EndpointRouter.started = false;
    Logger.info('EndpointRouter', 'network listener stopped');
  }

  /**
   * 登录/冷启动：remote 必须先通；local 后台探测，成功则加速覆盖。
   */
  static async bootstrap(auth?: SavedAuth): Promise<void> {
    const creds: SavedAuth | null = auth ?? AuthStore.getInstance().getCredentials();
    if (creds === null) {
      return;
    }
    await EndpointRouter.validateRemoteReachable(creds);
    await EndpointRouter.handBackToRemote('bootstrap');
    void EndpointRouter.tryActivateLocalBoost('bootstrap_local');
  }

  static async validateRemoteReachable(auth: SavedAuth): Promise<void> {
    const url: string = AuthContext.buildRestUrl('ping.view', [], auth, 'remote');
    await HttpTransport.probeRest(url);
  }

  static async activateLocalBoost(reason: SwitchReason, ssid?: string): Promise<void> {
    const from: EndpointType = EndpointRouter.getActiveEndpoint();
    if (from === 'local') {
      return;
    }
    await AuthStore.getInstance().setActiveEndpoint('local');
    EndpointRouter.syncAppStorage('local');
    if (ssid !== undefined && ssid.length > 0) {
      await WifiTrustCache.recordLocalSuccess(ssid);
    }
    EndpointRouter.emitChange(from, 'local', reason, ssid);
    Logger.info('EndpointRouter', `activateLocalBoost reason=${reason}`);
  }

  static async handBackToRemote(reason: SwitchReason): Promise<void> {
    const from: EndpointType = EndpointRouter.getActiveEndpoint();
    if (from === 'remote') {
      return;
    }
    await AuthStore.getInstance().setActiveEndpoint('remote');
    EndpointRouter.syncAppStorage('remote');
    EndpointRouter.emitChange(from, 'remote', reason);
    Logger.info('EndpointRouter', `handBackToRemote reason=${reason}`);
  }

  static async tryActivateLocalBoost(trigger: SwitchReason): Promise<void> {
    if (!EndpointRouter.canAttemptLocalProbe()) {
      return;
    }
    if (EndpointRouter.isProbingLocal) {
      return;
    }
    EndpointRouter.isProbingLocal = true;
    try {
      const creds: SavedAuth | null = AuthStore.getInstance().getCredentials();
      if (creds === null) {
        return;
      }
      const url: string = AuthContext.buildRestUrl('ping.view', [], creds, 'local');
      await HttpTransport.probeRest(url);
      const ssid: string = NetworkStatus.getWifiSsid();
      await EndpointRouter.activateLocalBoost(trigger === 'bootstrap_local' ? 'bootstrap_local' : 'probe_success',
        ssid);
      EndpointRouter.stopProbeSession();
    } catch (err) {
      Logger.warn('EndpointRouter', `local probe failed(${trigger}): ${(err as Error).message}`);
    } finally {
      EndpointRouter.isProbingLocal = false;
    }
  }

  private static canAttemptLocalProbe(): boolean {
    const store: AuthStore = AuthStore.getInstance();
    if (!store.isLoggedIn() || !store.hasLocalServerUrl()) {
      return false;
    }
    if (!NetworkStatus.isOnWifi()) {
      return false;
    }
    return true;
  }

  private static onNetCapabilitiesChange = (_info: connection.NetCapabilityInfo): void => {
    const currentType: string = NetworkStatus.getNetworkType();
    const previousType: string = EndpointRouter.lastNetworkType;
    EndpointRouter.lastNetworkType = currentType;
    AuthSessionRefreshNetworkType();
    NetworkStatus.refreshCachedWifiSsid();

    if (previousType !== 'wifi' && currentType === 'wifi') {
      const now: number = Date.now();
      if (now - EndpointRouter.lastWifiTriggerMs < WIFI_TRIGGER_DEBOUNCE_MS) {
        return;
      }
      EndpointRouter.lastWifiTriggerMs = now;
      EndpointRouter.probeSessionStopped = false;
      Logger.info('EndpointRouter', 'wifi available, schedule local boost probe');
      void EndpointRouter.scheduleLocalProbeSession('wifi_available');
      return;
    }

    if (previousType === 'wifi' && currentType === 'cellular') {
      EndpointRouter.stopProbeSession();
      void EndpointRouter.handBackToRemote('cellular');
      return;
    }
    if (previousType === 'wifi' && currentType !== 'wifi') {
      EndpointRouter.stopProbeSession();
      void EndpointRouter.handBackToRemote('probe_failed');
    }
  };

  private static scheduleLocalProbeSession(trigger: SwitchReason): void {
    if (EndpointRouter.probeSessionStopped) {
      return;
    }
    if (!EndpointRouter.canAttemptLocalProbe()) {
      return;
    }
    if (EndpointRouter.isLocalBoostActive()) {
      return;
    }
    EndpointRouter.probeAttempt = 0;
    void EndpointRouter.runProbeAttempt(trigger);
  }

  private static async runProbeAttempt(trigger: SwitchReason): Promise<void> {
    if (EndpointRouter.probeSessionStopped || EndpointRouter.isLocalBoostActive()) {
      return;
    }
    if (!EndpointRouter.canAttemptLocalProbe()) {
      return;
    }
    const ssid: string = NetworkStatus.getWifiSsid();
    const trusted: boolean = WifiTrustCache.isTrusted(ssid);
    const maxAttempts: number = trusted ? TRUSTED_PROBE_MAX_ATTEMPTS : UNKNOWN_PROBE_MAX_ATTEMPTS;
    const intervalMs: number = trusted ? TRUSTED_PROBE_INTERVAL_MS : UNKNOWN_PROBE_INTERVAL_MS;

    EndpointRouter.probeAttempt++;
    try {
      await EndpointRouter.tryActivateLocalBoost(trigger);
      if (EndpointRouter.isLocalBoostActive()) {
        return;
      }
    } catch (_err) {
    }

    if (EndpointRouter.probeAttempt >= maxAttempts) {
      EndpointRouter.probeSessionStopped = true;
      if (trusted && ssid.length > 0) {
        await WifiTrustCache.remove(ssid);
        Logger.warn('EndpointRouter', `trusted wifi probe exhausted, removed ssid=${ssid}`);
      } else {
        Logger.info('EndpointRouter', 'unknown wifi probe exhausted, stay on remote');
      }
      return;
    }

    if (EndpointRouter.probeTimerId !== null) {
      clearTimeout(EndpointRouter.probeTimerId);
    }
    EndpointRouter.probeTimerId = setTimeout(() => {
      EndpointRouter.probeTimerId = null;
      void EndpointRouter.runProbeAttempt(trigger);
    }, intervalMs);
  }

  private static stopProbeSession(): void {
    EndpointRouter.probeSessionStopped = true;
    if (EndpointRouter.probeTimerId !== null) {
      clearTimeout(EndpointRouter.probeTimerId);
      EndpointRouter.probeTimerId = null;
    }
  }

  private static syncAppStorage(endpoint: EndpointType): void {
    const creds: SavedAuth | null = AuthStore.getInstance().getCredentials();
    if (creds === null) {
      return;
    }
    const activeServer: string = AuthStore.resolveEndpointUrl(creds, endpoint);
    AppStorage.setOrCreate<string>('loggedInServer', activeServer);
    AppStorage.setOrCreate<string>('loggedInEndpoint', endpoint);
  }

  private static emitChange(from: EndpointType, to: EndpointType, reason: SwitchReason,
    ssid?: string): void {
    if (from === to) {
      return;
    }
    const event: EndpointChangeEvent = { from, to, reason, ssid };
    for (let i: number = 0; i < EndpointRouter.listeners.length; i++) {
      try {
        EndpointRouter.listeners[i](event);
      } catch (err) {
        Logger.warn('EndpointRouter', `listener error: ${(err as Error).message}`);
      }
    }
  }
}

function AuthSessionRefreshNetworkType(): void {
  AppStorage.setOrCreate<string>('networkType', NetworkStatus.getNetworkType());
}
