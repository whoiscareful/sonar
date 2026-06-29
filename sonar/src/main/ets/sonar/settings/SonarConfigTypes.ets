export const SONAR_CONFIG_VERSION: number = 1;

export const DEFAULT_CONFIG_PASSWORD: string = 'sonar';

export interface SonarConfigPayload {
  v: number;
  remoteServerUrl: string;
  localServerUrl: string;
  username: string;
  password: string;
}

export interface SonarConfigEnvelope {
  v: number;
  salt: string;
  iv: string;
  tag: string;
  data: string;
}
