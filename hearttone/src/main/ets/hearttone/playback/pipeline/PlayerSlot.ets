import { StreamResource } from '../../network/media/StreamResource';
import { AudioRenderSink } from './AudioRenderSink';

type PlaybackSource = 'local' | 'remote';

/** 单路 AVPlayer 槽位，active / standby 共用 */
export class PlayerSlot {
  readonly sink: AudioRenderSink = new AudioRenderSink();
  streamResource: StreamResource | null = null;
  songId: string = '';
  playbackSource: PlaybackSource = 'remote';
  localPath: string = '';
  standbyReady: boolean = false;

  async release(): Promise<void> {
    if (this.streamResource !== null) {
      this.streamResource.cancelToken.cancel();
      this.streamResource = null;
    }
    this.sink.setStandbyPreparedCallback(null);
    this.sink.setStandbyFailedCallback(null);
    await this.sink.release();
    this.songId = '';
    this.localPath = '';
    this.playbackSource = 'remote';
    this.standbyReady = false;
  }
}
