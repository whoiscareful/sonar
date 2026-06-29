import { Logger } from '../../common/Logger';
import { EndpointChangeEvent } from '../../network/routing/EndpointTypes';

export interface PlaybackPipelineNetworkHandler {
  onNetworkPathChanged(event: EndpointChangeEvent): void;
}

/**
 * 方案 F 播放管线接入点；当前为 AVPlayer 过渡实现。
 */
export class PlaybackPipelineBridge {
  private static handler: PlaybackPipelineNetworkHandler | null = null;

  static register(handler: PlaybackPipelineNetworkHandler): void {
    PlaybackPipelineBridge.handler = handler;
  }

  static unregister(): void {
    PlaybackPipelineBridge.handler = null;
  }

  static notifyNetworkPathChanged(event: EndpointChangeEvent): void {
    if (PlaybackPipelineBridge.handler === null) {
      Logger.info('PlaybackPipelineBridge',
        `network path changed ${event.from}->${event.to} reason=${event.reason} (no handler)`);
      return;
    }
    PlaybackPipelineBridge.handler.onNetworkPathChanged(event);
  }
}
