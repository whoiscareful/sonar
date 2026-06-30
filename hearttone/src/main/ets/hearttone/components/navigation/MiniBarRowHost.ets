import {
  BAR_TONE_MINI_TARGET_INACTIVE_KEY,
  BAR_TONE_MINI_TARGET_PRIMARY_KEY,
  BAR_TONE_MINI_TARGET_SECONDARY_KEY
} from '../../ui/color/BarToneStore';
import { MiniBarRow } from './MiniBarRow';

/** miniBar 稳定入口：目标色经 AppStorage 注入，与页签逐帧配色解耦。 */
@Component
export struct MiniBarRowHost {
  @StorageLink(BAR_TONE_MINI_TARGET_INACTIVE_KEY) targetInactive: string = '#282A32';
  @StorageLink(BAR_TONE_MINI_TARGET_PRIMARY_KEY) targetPrimary: string = '#1B1D23';
  @StorageLink(BAR_TONE_MINI_TARGET_SECONDARY_KEY) targetSecondary: string = '#3C3F4A';

  build() {
    MiniBarRow({
      targetInactive: this.targetInactive,
      targetPrimary: this.targetPrimary,
      targetSecondary: this.targetSecondary
    })
  }
}
