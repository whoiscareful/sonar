import { EndpointChangeEvent } from '../../network/routing/EndpointTypes';
import { Logger } from '../../common/Logger';
import { PlaybackPipelineBridge, PlaybackPipelineNetworkHandler } from './PlaybackPipelineBridge';

export type NetworkPathChangedHandler = (event: EndpointChangeEvent) => void | Promise<void>;

class PlaybackPipelineNetworkBridge implements PlaybackPipelineNetworkHandler {
  onNetworkPathChanged(event: EndpointChangeEvent): void {
    void PlaybackPipeline.handleNetworkPathChanged(event);
  }
}

/**
 * 播放管线门面：endpoint 变更 → PipelineOrchestrator.migrateInPlace。
 */
export class PlaybackPipeline {
  private static networkHandler: NetworkPathChangedHandler | null = null;
  private static currentSongId: string = '';
  private static readonly bridgeAdapter: PlaybackPipelineNetworkBridge = new PlaybackPipelineNetworkBridge();

  static initialize(): void {
    PlaybackPipelineBridge.register(PlaybackPipeline.bridgeAdapter);
  }

  static setNetworkPathChangedHandler(handler: NetworkPathChangedHandler | null): void {
    PlaybackPipeline.networkHandler = handler;
  }

  static onTrackStarted(songId: string): void {
    PlaybackPipeline.currentSongId = songId;
  }

  static onTrackStopped(): void {
    PlaybackPipeline.currentSongId = '';
  }

  static getCurrentSongId(): string {
    return PlaybackPipeline.currentSongId;
  }

  static async handleNetworkPathChanged(event: EndpointChangeEvent): Promise<void> {
    if (PlaybackPipeline.networkHandler === null) {
      Logger.info('PlaybackPipeline',
        `network path changed ${event.from}->${event.to} reason=${event.reason} (no handler)`);
      return;
    }
    await PlaybackPipeline.networkHandler(event);
  }
}
