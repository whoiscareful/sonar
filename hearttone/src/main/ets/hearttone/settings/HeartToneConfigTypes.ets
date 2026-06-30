export const hearttone_CONFIG_VERSION: number = 1;

export const DEFAULT_CONFIG_PASSWORD: string = 'hearttone';

export interface HeartToneConfigPayload {
  v: number;
  remoteServerUrl: string;
  localServerUrl: string;
  username: string;
  password: string;
}

export interface HeartToneConfigEnvelope {
  v: number;
  salt: string;
  iv: string;
  tag: string;
  data: string;
}
