import { taskpool } from '@kit.ArkTS';
import { parseJsonTextConcurrent } from './JsonParseTask';
import { averageBottomBandFromBufferConcurrent } from './PixelAverageTask';
import {
  CoverReconcileResult,
  reconcileCoverIndexConcurrent,
  reconcileSongIndexConcurrent,
  ReconcileEntryInput,
  ReconcileFileStat,
  SongReconcileResult
} from './CacheIndexReconcileTask';
import { parseSubsonicEnvelopeConcurrent } from './SubsonicParseTask';

export class TaskPoolRunner {
  private static wrapTaskError(err: Object): Error {
    if (err instanceof Error) {
      return err;
    }
    return new Error(String(err));
  }

  static async parseJsonText<T>(text: string): Promise<T> {
    try {
      const serialized: Object = await taskpool.execute(parseJsonTextConcurrent, text);
      return JSON.parse(serialized as string) as T;
    } catch (err) {
      throw TaskPoolRunner.wrapTaskError(err as Object);
    }
  }

  static async parseSubsonicEnvelopeJson<T>(text: string): Promise<T> {
    try {
      const serialized: Object = await taskpool.execute(parseSubsonicEnvelopeConcurrent, text);
      return JSON.parse(serialized as string) as T;
    } catch (err) {
      throw TaskPoolRunner.wrapTaskError(err as Object);
    }
  }

  static async averageBottomBandFromBuffer(
    buffer: ArrayBuffer,
    regionWidth: number,
    bandHeight: number,
    bytesPerPixel: number
  ): Promise<string> {
    try {
      const hex: Object = await taskpool.execute(
        averageBottomBandFromBufferConcurrent,
        buffer,
        regionWidth,
        bandHeight,
        bytesPerPixel
      );
      return hex as string;
    } catch (err) {
      throw TaskPoolRunner.wrapTaskError(err as Object);
    }
  }

  static async reconcileCoverIndex(
    entries: ReconcileEntryInput[],
    diskFiles: ReconcileFileStat[],
    minCompleteBytes: number
  ): Promise<CoverReconcileResult> {
    try {
      const result: Object = await taskpool.execute(
        reconcileCoverIndexConcurrent,
        entries,
        diskFiles,
        minCompleteBytes
      );
      return result as CoverReconcileResult;
    } catch (err) {
      throw TaskPoolRunner.wrapTaskError(err as Object);
    }
  }

  static async reconcileSongIndex(
    entries: ReconcileEntryInput[],
    diskFiles: ReconcileFileStat[],
    minCompleteBytes: number
  ): Promise<SongReconcileResult> {
    try {
      const result: Object = await taskpool.execute(
        reconcileSongIndexConcurrent,
        entries,
        diskFiles,
        minCompleteBytes
      );
      return result as SongReconcileResult;
    } catch (err) {
      throw TaskPoolRunner.wrapTaskError(err as Object);
    }
  }
}
