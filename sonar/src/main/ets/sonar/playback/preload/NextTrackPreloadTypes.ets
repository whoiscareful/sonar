import { Song } from '../../api/SubsonicTypes';
import { EndpointType } from '../../auth/AuthStore';
import { CancelToken } from '../../network/transport/CancelToken';
import { StreamResource } from '../../network/media/StreamResource';
import { PlaybackPhase } from '../PlaybackSnapshot';

export const NEXT_PRELOAD_REMAINING_MS: number = 30_000;
export const STREAM_WARMUP_TARGET_BYTES: number = 512 * 1024;

export enum PreloadPhase {
  Idle = 'idle',
  Running = 'running'
}

export interface PreloadContext {
  currentSongId: string;
  nextSong: Song;
  remainingMs: number;
  durationMs: number;
  phase: PlaybackPhase;
  endpoint: EndpointType;
}

export type PreloadHandleKind = 'skip' | 'download' | 'standby' | 'streamWarmup';

export interface PreloadHandle {
  kind: PreloadHandleKind;
  songId: string;
  cancelToken?: CancelToken;
  streamResource?: StreamResource;
}

export interface PreloadTiming {
  durationMs: number;
  remainingMs: number;
}

/** 从当前曲 metadata / sink / 队列 duration 推算 remainingMs */
export function resolvePreloadRemainingMs(
  positionMs: number,
  orchestratorDurationMs: number,
  snapshotTrackDurationMs: number,
  queueSongDurationSec: number
): PreloadTiming {
  let durationMs: number = orchestratorDurationMs;
  if (durationMs <= 0 && snapshotTrackDurationMs > 0) {
    durationMs = snapshotTrackDurationMs;
  }
  if (durationMs <= 0 && queueSongDurationSec > 0) {
    durationMs = queueSongDurationSec * 1000;
  }
  if (durationMs <= 0) {
    const empty: PreloadTiming = { durationMs: 0, remainingMs: 0 };
    return empty;
  }
  let remainingMs: number = durationMs - positionMs;
  if (remainingMs < 0) {
    remainingMs = 0;
  }
  const timing: PreloadTiming = { durationMs: durationMs, remainingMs: remainingMs };
  return timing;
}
