import { ColorUtil } from './ColorUtil';

const TONE_COLOR_FRAME_MS: number = 16;

export class BarToneColorAnimator {
  private timerId: number = -1;

  stop(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  animateHex(from: string, to: string, durationMs: number, onFrame: (value: string) => void): void {
    this.stop();
    if (from === to) {
      onFrame(to);
      return;
    }
    const steps: number = Math.max(1, Math.floor(durationMs / TONE_COLOR_FRAME_MS));
    let step: number = 0;
    this.timerId = setInterval(() => {
      step++;
      const ratio: number = Math.min(1, step / steps);
      onFrame(ColorUtil.blendHex(from, to, ratio));
      if (step >= steps) {
        this.stop();
      }
    }, TONE_COLOR_FRAME_MS) as number;
  }

  animateTriple(
    fromInactive: string,
    toInactive: string,
    fromPrimary: string,
    toPrimary: string,
    fromSecondary: string,
    toSecondary: string,
    durationMs: number,
    onFrame: (inactive: string, primary: string, secondary: string) => void
  ): void {
    this.stop();
    const steps: number = Math.max(1, Math.floor(durationMs / TONE_COLOR_FRAME_MS));
    let step: number = 0;
    this.timerId = setInterval(() => {
      step++;
      const ratio: number = Math.min(1, step / steps);
      onFrame(
        ColorUtil.blendHex(fromInactive, toInactive, ratio),
        ColorUtil.blendHex(fromPrimary, toPrimary, ratio),
        ColorUtil.blendHex(fromSecondary, toSecondary, ratio)
      );
      if (step >= steps) {
        this.stop();
      }
    }, TONE_COLOR_FRAME_MS) as number;
  }
}
