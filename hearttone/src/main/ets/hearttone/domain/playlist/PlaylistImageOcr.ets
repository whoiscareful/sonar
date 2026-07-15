import { fileIo } from '@kit.CoreFileKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { Logger } from '../../common/Logger';

interface OcrFailure {
  code?: number;
  message?: string;
}

const MAX_OCR_EDGE: number = 2400;

export class PlaylistImageOcr {
  static async recognize(uri: string): Promise<string> {
    let file: fileIo.File | null = null;
    let source: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    let initialized: boolean = false;
    let stage: string = '读取图片';
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      source = image.createImageSource(file.fd);

      stage = '解码图片';
      const info: image.ImageInfo = await source.getImageInfo();
      const options: image.DecodingOptions = {
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      const width: number = info.size.width;
      const height: number = info.size.height;
      const longestEdge: number = Math.max(width, height);
      if (longestEdge > MAX_OCR_EDGE) {
        const scale: number = MAX_OCR_EDGE / longestEdge;
        options.desiredSize = {
          width: Math.max(1, Math.round(width * scale)),
          height: Math.max(1, Math.round(height * scale))
        };
      }
      pixelMap = await source.createPixelMap(options);

      stage = '初始化文字识别';
      initialized = await textRecognition.init();
      if (!initialized) {
        throw new Error('设备文字识别服务初始化失败');
      }

      stage = '识别文字';
      const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const result: textRecognition.TextRecognitionResult = await textRecognition.recognizeText(visionInfo, {
        isDirectionDetectionSupported: true
      });
      Logger.info('PlaylistImageOcr', `recognized ${result.value.length} characters from ${width}x${height}`);
      return result.value.trim();
    } catch (err) {
      const failure: OcrFailure = err as OcrFailure;
      const detail: string = failure.message ?? '未知错误';
      const codeText: string = failure.code === undefined ? '' : `（错误码 ${failure.code}）`;
      Logger.error('PlaylistImageOcr', `${stage} failed: ${detail}${codeText}`);
      throw new Error(`${stage}失败：${detail}${codeText}`);
    } finally {
      if (initialized) {
        try {
          await textRecognition.release();
        } catch (_err) {
        }
      }
      if (pixelMap !== null) {
        try {
          await pixelMap.release();
        } catch (_err) {
        }
      }
      if (source !== null) {
        try {
          await source.release();
        } catch (_err) {
        }
      }
      if (file !== null) {
        try {
          fileIo.closeSync(file);
        } catch (_err) {
        }
      }
    }
  }
}
