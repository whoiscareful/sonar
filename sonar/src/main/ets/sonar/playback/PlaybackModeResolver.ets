import { PlaybackMode } from './PlaybackSnapshot';
import { ShuffleController } from './ShuffleController';

export interface PlaybackNavResult {
  index: number;
  shuffleCursor: number;
  reshuffleOrder: number[] | null;
}

export function resolveNextPlayback(
  queueSize: number,
  currentIndex: number,
  mode: PlaybackMode,
  manual: boolean,
  shuffleOrder: number[],
  shuffleCursor: number
): PlaybackNavResult {
  if (queueSize <= 1) {
    return { index: 0, shuffleCursor: 0, reshuffleOrder: null };
  }
  if (mode === 'random') {
    if (shuffleOrder.length === 0) {
      const freshOrder: number[] = ShuffleController.buildShuffleOrder(queueSize, currentIndex);
      const nextCursor: number = freshOrder.length > 1 ? 1 : 0;
      return {
        index: freshOrder[nextCursor],
        shuffleCursor: nextCursor,
        reshuffleOrder: freshOrder
      };
    }
    const advance = ShuffleController.advance(shuffleCursor, shuffleOrder.length);
    if (advance.completedCycle) {
      const newOrder: number[] = ShuffleController.buildShuffleOrder(queueSize, currentIndex);
      const nextCursor: number = newOrder.length > 1 ? 1 : 0;
      return {
        index: newOrder[nextCursor],
        shuffleCursor: nextCursor,
        reshuffleOrder: newOrder
      };
    }
    return {
      index: shuffleOrder[advance.nextCursor],
      shuffleCursor: advance.nextCursor,
      reshuffleOrder: null
    };
  }
  if (!manual && mode === 'singleLoop') {
    return { index: currentIndex, shuffleCursor: 0, reshuffleOrder: null };
  }
  let nextIndex: number = currentIndex + 1;
  if (nextIndex >= queueSize) {
    nextIndex = 0;
  }
  return { index: nextIndex, shuffleCursor: 0, reshuffleOrder: null };
}

export function resolvePreviousPlayback(
  queueSize: number,
  currentIndex: number,
  mode: PlaybackMode,
  shuffleOrder: number[],
  shuffleCursor: number
): PlaybackNavResult {
  if (queueSize <= 1) {
    return { index: 0, shuffleCursor: 0, reshuffleOrder: null };
  }
  if (mode === 'random') {
    if (shuffleOrder.length === 0) {
      return { index: currentIndex, shuffleCursor: 0, reshuffleOrder: null };
    }
    let prevCursor: number = shuffleCursor - 1;
    if (prevCursor < 0) {
      prevCursor = shuffleOrder.length - 1;
    }
    return {
      index: shuffleOrder[prevCursor],
      shuffleCursor: prevCursor,
      reshuffleOrder: null
    };
  }
  let prevIndex: number = currentIndex - 1;
  if (prevIndex < 0) {
    prevIndex = queueSize - 1;
  }
  return { index: prevIndex, shuffleCursor: 0, reshuffleOrder: null };
}

/** @deprecated 保留兼容，内部转发至 resolveNextPlayback */
export function resolveNextIndex(
  queue: Object[],
  currentIndex: number,
  mode: PlaybackMode,
  manual: boolean
): number {
  const result: PlaybackNavResult = resolveNextPlayback(
    queue.length,
    currentIndex,
    mode,
    manual,
    [],
    0
  );
  return result.index;
}

/** @deprecated 保留兼容，内部转发至 resolvePreviousPlayback */
export function resolvePreviousIndex(queue: Object[], currentIndex: number): number {
  const result: PlaybackNavResult = resolvePreviousPlayback(queue.length, currentIndex, 'listLoop', [], 0);
  return result.index;
}
