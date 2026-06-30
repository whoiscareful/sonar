import { SystemMaterialParams, hdsMaterial } from '@kit.UIDesignKit';
import deviceInfo from '@ohos.deviceInfo';

const HDS_MATERIAL_AVAILABLE_KEY: string = 'hdsMaterialAvailable';

export class ImmersiveMaterialHelper {
  static probeAndCache(): void {
    let available: boolean = false;
    try {
      if (deviceInfo.distributionOSApiVersion >= 60100) {
        const supportedTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
        available = supportedTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
      }
    } catch (_err) {
      available = false;
    }
    AppStorage.setOrCreate<boolean>(HDS_MATERIAL_AVAILABLE_KEY, available);
  }

  static buildNavigationEffect(): SystemMaterialParams {
    const available: boolean = AppStorage.get<boolean>(HDS_MATERIAL_AVAILABLE_KEY) ?? false;
    if (!available) {
      return {
        materialType: hdsMaterial.MaterialType.NONE,
        materialLevel: hdsMaterial.MaterialLevel.SMOOTH
      };
    }
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    };
  }

  /** 标题栏沉浸光感：对齐官方示例 IMMERSIVE + ADAPTIVE */
  static buildTitleBarEffect(): SystemMaterialParams {
    const available: boolean = AppStorage.get<boolean>(HDS_MATERIAL_AVAILABLE_KEY) ?? false;
    if (!available) {
      return {
        materialType: hdsMaterial.MaterialType.NONE,
        materialLevel: hdsMaterial.MaterialLevel.SMOOTH
      };
    }
    return {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    };
  }
}
