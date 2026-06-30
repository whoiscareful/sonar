import { PipelineOrchestrator } from '../pipeline/PipelineOrchestrator';
import { StreamResource } from '../../network/media/StreamResource';
import { PreloadContext, PreloadHandle } from './NextTrackPreloadTypes';

export interface PreloadDeps {
  orchestrator: PipelineOrchestrator;
  openStream: (songId: string) => StreamResource;
  enqueueDownload: (songId: string) => void;
  isComplete: (songId: string) => boolean;
  shouldAutoCacheNow: () => boolean;
  isStandbyCapable: () => boolean;
  onStandbyPrepareFailed: (songId: string) => void;
}

export interface NextTrackPreloadStrategy {
  readonly name: string;
  canApply(ctx: PreloadContext, deps: PreloadDeps): boolean;
  start(ctx: PreloadContext, deps: PreloadDeps): PreloadHandle;
  cancel(handle: PreloadHandle, deps: PreloadDeps): void;
}
