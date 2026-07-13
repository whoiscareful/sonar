export const hearttone_CONFIG_VERSION: number = 1;

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
