export type HttpProfile = 'json' | 'probe' | 'binarySmall' | 'binaryStream';

export interface HttpProfileConfig {
  connectTimeoutMs: number;
  readTimeoutMs: number;
  maxAttemptsOnSameEndpoint: number;
}

const JSON_PROFILE: HttpProfileConfig = {
  connectTimeoutMs: 10000,
  readTimeoutMs: 15000,
  maxAttemptsOnSameEndpoint: 2
};

const PROBE_PROFILE: HttpProfileConfig = {
  connectTimeoutMs: 3000,
  readTimeoutMs: 5000,
  maxAttemptsOnSameEndpoint: 1
};

const BINARY_SMALL_PROFILE: HttpProfileConfig = {
  connectTimeoutMs: 8000,
  readTimeoutMs: 12000,
  maxAttemptsOnSameEndpoint: 2
};

const BINARY_STREAM_PROFILE: HttpProfileConfig = {
  connectTimeoutMs: 10000,
  readTimeoutMs: 120000,
  maxAttemptsOnSameEndpoint: 1
};

export function getHttpProfileConfig(profile: HttpProfile): HttpProfileConfig {
  if (profile === 'json') {
    return JSON_PROFILE;
  }
  if (profile === 'probe') {
    return PROBE_PROFILE;
  }
  if (profile === 'binarySmall') {
    return BINARY_SMALL_PROFILE;
  }
  return BINARY_STREAM_PROFILE;
}
