import { image } from '@kit.ImageKit';

export enum CoverDecodePriority {
  PINNED = 0,
  PLAYBACK = 1,
  NORMAL = 2
}

interface DecodeJob {
  coverArtId: string;
  path: string;
  priority: CoverDecodePriority;
  resolve: (pixelMap: image.PixelMap | null) => void;
}

export class CoverDecodeScheduler {
  private static jobs: DecodeJob[] = [];
  private static running: number = 0;
  private static readonly MAX_CONCURRENT: number = 1;
  private static decodeFn: ((path: string) => Promise<image.PixelMap | null>) | null = null;
  private static inflightByCoverId: Map<string, Promise<image.PixelMap | null>> = new Map();

  static setDecodeFn(fn: (path: string) => Promise<image.PixelMap | null>): void {
    CoverDecodeScheduler.decodeFn = fn;
  }

  static schedule(
    coverArtId: string,
    path: string,
    priority: CoverDecodePriority
  ): Promise<image.PixelMap | null> {
    const inflight: Promise<image.PixelMap | null> | undefined =
      CoverDecodeScheduler.inflightByCoverId.get(coverArtId);
    if (inflight !== undefined) {
      return inflight;
    }

    const promise: Promise<image.PixelMap | null> = new Promise(
      (resolve: (pixelMap: image.PixelMap | null) => void) => {
        CoverDecodeScheduler.jobs.push({
          coverArtId,
          path,
          priority,
          resolve
        });
        CoverDecodeScheduler.sortJobs();
        void CoverDecodeScheduler.pump();
      }
    );

    CoverDecodeScheduler.inflightByCoverId.set(coverArtId, promise);
    promise.finally(() => {
      CoverDecodeScheduler.inflightByCoverId.delete(coverArtId);
    });
    return promise;
  }

  private static sortJobs(): void {
    CoverDecodeScheduler.jobs.sort((left: DecodeJob, right: DecodeJob): number => {
      return left.priority - right.priority;
    });
  }

  private static async pump(): Promise<void> {
    while (CoverDecodeScheduler.running < CoverDecodeScheduler.MAX_CONCURRENT &&
      CoverDecodeScheduler.jobs.length > 0) {
      const job: DecodeJob | undefined = CoverDecodeScheduler.jobs.shift();
      if (job === undefined) {
        break;
      }
      CoverDecodeScheduler.running++;
      try {
        const fn: ((path: string) => Promise<image.PixelMap | null>) | null =
          CoverDecodeScheduler.decodeFn;
        const pixelMap: image.PixelMap | null = fn !== null ? await fn(job.path) : null;
        job.resolve(pixelMap);
      } catch (_err) {
        job.resolve(null);
      } finally {
        CoverDecodeScheduler.running--;
      }
    }
    if (CoverDecodeScheduler.jobs.length > 0 &&
      CoverDecodeScheduler.running < CoverDecodeScheduler.MAX_CONCURRENT) {
      void CoverDecodeScheduler.pump();
    }
  }
}
