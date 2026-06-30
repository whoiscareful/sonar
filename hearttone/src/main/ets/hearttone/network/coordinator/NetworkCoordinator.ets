import { Logger } from '../../common/Logger';
import { EndpointRouter } from '../routing/EndpointRouter';
import { EndpointChangeEvent } from '../routing/EndpointTypes';
import { PlaybackPipelineBridge } from '../../playback/pipeline/PlaybackPipelineBridge';
import { MediaResourceService } from '../media/MediaResourceService';

export class NetworkCoordinator {
  private static unsubscribe: (() => void) | null = null;
  private static initialized: boolean = false;

  static init(): void {
    if (NetworkCoordinator.initialized) {
      return;
    }
    NetworkCoordinator.initialized = true;
    NetworkCoordinator.unsubscribe = EndpointRouter.subscribe((event: EndpointChangeEvent): void => {
      NetworkCoordinator.onEndpointChanged(event);
    });
    Logger.info('NetworkCoordinator', 'subscribed to EndpointRouter');
  }

  static shutdown(): void {
    if (NetworkCoordinator.unsubscribe !== null) {
      NetworkCoordinator.unsubscribe();
      NetworkCoordinator.unsubscribe = null;
    }
    NetworkCoordinator.initialized = false;
  }

  private static onEndpointChanged(event: EndpointChangeEvent): void {
    Logger.info('NetworkCoordinator',
      `endpoint ${event.from}->${event.to} reason=${event.reason} ssid=${event.ssid ?? ''}`);
    MediaResourceService.migrateActiveStreams(event.to);
    PlaybackPipelineBridge.notifyNetworkPathChanged(event);
  }
}
