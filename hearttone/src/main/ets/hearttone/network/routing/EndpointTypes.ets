import { EndpointType } from '../../auth/AuthStore';

export type { EndpointType };

export type SwitchReason =
  | 'bootstrap'
  | 'bootstrap_local'
  | 'wifi_available'
  | 'cellular'
  | 'probe_success'
  | 'probe_failed'
  | 'request_fallback'
  | 'manual';

export interface EndpointChangeEvent {
  from: EndpointType;
  to: EndpointType;
  reason: SwitchReason;
  ssid?: string;
}

export type EndpointChangeListener = (event: EndpointChangeEvent) => void;
