import { media } from '@kit.MediaKit';
import { Logger } from '../../common/Logger';

/** 探测是否可创建第二路 AVPlayer 作 standby 预加载 */
export class PreloadDeviceCapability {
  private static standbyCapable: boolean = true;
  private static probed: boolean = false;

  static async probe(): Promise<void> {
    if (PreloadDeviceCapability.probed) {
      return;
    }
    PreloadDeviceCapability.probed = true;
    try {
      const probePlayer: media.AVPlayer = await media.createAVPlayer();
      await probePlayer.release();
      PreloadDeviceCapability.standbyCapable = true;
    } catch (err) {
      PreloadDeviceCapability.standbyCapable = false;
      Logger.warn('PreloadDeviceCapability', `standby probe failed: ${(err as Error).message}`);
    }
  }

  static isStandbyCapable(): boolean {
    return PreloadDeviceCapability.standbyCapable;
  }
}
