export class ShuffleAdvanceResult {
  nextCursor: number = 0;
  completedCycle: boolean = false;
}

export class ShuffleController {
  static buildShuffleOrder(queueSize: number, anchorIndex: number): number[] {
    if (queueSize <= 0) {
      return [];
    }
    if (queueSize === 1) {
      return [0];
    }
    const safeAnchor: number = anchorIndex >= 0 && anchorIndex < queueSize ? anchorIndex : 0;
    const rest: number[] = [];
    for (let i: number = 0; i < queueSize; i++) {
      if (i !== safeAnchor) {
        rest.push(i);
      }
    }
    for (let i: number = rest.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: number = rest[i];
      rest[i] = rest[j];
      rest[j] = tmp;
    }
    return [safeAnchor, ...rest];
  }

  static advance(cursor: number, orderLength: number): ShuffleAdvanceResult {
    const result: ShuffleAdvanceResult = new ShuffleAdvanceResult();
    result.nextCursor = cursor + 1;
    result.completedCycle = result.nextCursor >= orderLength;
    return result;
  }

  static remapAfterInsert(order: number[], insertAt: number, insertAfterCursor: number): number[] {
    const remapped: number[] = [];
    for (let i: number = 0; i < order.length; i++) {
      let idx: number = order[i];
      if (idx >= insertAt) {
        idx += 1;
      }
      remapped.push(idx);
    }
    const newOrder: number[] = [];
    for (let i: number = 0; i < remapped.length; i++) {
      newOrder.push(remapped[i]);
      if (i === insertAfterCursor) {
        newOrder.push(insertAt);
      }
    }
    if (insertAfterCursor >= remapped.length) {
      newOrder.push(insertAt);
    }
    return newOrder;
  }

  static remapAfterRemove(order: number[], removeAt: number): number[] {
    const result: number[] = [];
    for (let i: number = 0; i < order.length; i++) {
      const idx: number = order[i];
      if (idx === removeAt) {
        continue;
      }
      if (idx > removeAt) {
        result.push(idx - 1);
      } else {
        result.push(idx);
      }
    }
    return result;
  }

  static findCursorForIndex(order: number[], targetIndex: number): number {
    for (let i: number = 0; i < order.length; i++) {
      if (order[i] === targetIndex) {
        return i;
      }
    }
    return -1;
  }
}
