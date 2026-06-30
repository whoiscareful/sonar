import { fileIo, WriteOptions } from '@kit.CoreFileKit';
import { CacheFileUtil } from '../common/CacheFileUtil';
import { AuthContext } from '../network/auth/AuthContext';
import { EndpointRouter } from '../network/routing/EndpointRouter';
import { HttpTransport } from '../network/transport/HttpTransport';
import { CancelToken } from '../network/transport/CancelToken';
import { Logger } from '../common/Logger';

const MIN_COMPLETE_BYTES: number = 4096;
const WRITE_BUFFER_FLUSH_BYTES: number = 64 * 1024;

export interface SongCacheWriteCallbacks {
  onComplete: (sizeBytes: number) => void;
  onError: (message: string) => void;
}

export class SongCacheWriter {
  private cancelToken: CancelToken | null = null;
  private activeSongId: string = '';

  getActiveSongId(): string {
    return this.activeSongId;
  }

  isBusy(): boolean {
    return this.cancelToken !== null && !this.cancelToken.isCancelled;
  }

  cancel(songId?: string): void {
    if (this.cancelToken === null) {
      return;
    }
    if (songId !== undefined && songId.length > 0 && this.activeSongId !== songId) {
      return;
    }
    this.cancelToken.cancel();
    this.cancelToken = null;
    this.activeSongId = '';
  }

  async streamToFile(
    songId: string,
    partPath: string,
    finalPath: string,
    callbacks: SongCacheWriteCallbacks
  ): Promise<void> {
    if (this.isBusy()) {
      throw new Error('download already in progress');
    }
    CacheFileUtil.ensureParentDir(partPath);
    CacheFileUtil.removeIfExists(partPath);
    const cancelToken: CancelToken = new CancelToken();
    this.cancelToken = cancelToken;
    this.activeSongId = songId;
    const endpoint = EndpointRouter.getActiveEndpoint();
    const url: string = AuthContext.buildMediaUrl('stream', ['id', songId], undefined, endpoint);
    let file: fileIo.File | null = null;
    let writeOffset: number = 0;
    let pendingChunks: ArrayBuffer[] = [];
    let pendingBytes: number = 0;

    const flushPendingWrites = (): void => {
      if (file === null || pendingBytes === 0) {
        pendingChunks = [];
        pendingBytes = 0;
        return;
      }
      for (let i: number = 0; i < pendingChunks.length; i++) {
        const chunk: ArrayBuffer = pendingChunks[i];
        const writeOptions: WriteOptions = {
          offset: writeOffset,
          length: chunk.byteLength
        };
        fileIo.writeSync(file.fd, chunk, writeOptions);
        writeOffset += chunk.byteLength;
      }
      pendingChunks = [];
      pendingBytes = 0;
    };

    try {
      file = fileIo.openSync(partPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      await new Promise<void>((resolve, reject) => {
        HttpTransport.openStream({
          url: url,
          byteOffset: 0,
          cancelToken: cancelToken,
          onChunk: (chunk: ArrayBuffer): void => {
            if (file === null || cancelToken.isCancelled) {
              return;
            }
            pendingChunks.push(chunk);
            pendingBytes += chunk.byteLength;
            if (pendingBytes >= WRITE_BUFFER_FLUSH_BYTES) {
              flushPendingWrites();
            }
          },
          onComplete: (): void => {
            resolve();
          },
          onError: (err: Error): void => {
            reject(err);
          }
        });
      });
      flushPendingWrites();
      if (cancelToken.isCancelled) {
        throw new Error('download cancelled');
      }
      if (writeOffset < MIN_COMPLETE_BYTES) {
        throw new Error(`download too small: ${writeOffset} bytes`);
      }
      if (file !== null) {
        try {
          fileIo.closeSync(file);
        } catch (_err) {
        }
        file = null;
      }
      CacheFileUtil.removeIfExists(finalPath);
      fileIo.renameSync(partPath, finalPath);
      this.cancelToken = null;
      this.activeSongId = '';
      callbacks.onComplete(writeOffset);
    } catch (err) {
      if (file !== null) {
        try {
          fileIo.closeSync(file);
        } catch (_err) {
        }
      }
      CacheFileUtil.removeIfExists(partPath);
      this.cancelToken = null;
      this.activeSongId = '';
      const message: string = (err as Error).message;
      Logger.warn('SongCacheWriter', `streamToFile failed songId=${songId}: ${message}`);
      callbacks.onError(message);
      throw new Error(message);
    }
  }

}
