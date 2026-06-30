@Concurrent
export function averageBottomBandFromBufferConcurrent(
  buffer: ArrayBuffer,
  regionWidth: number,
  bandHeight: number,
  bytesPerPixel: number
): string {
  const pixels: Uint8Array = new Uint8Array(buffer);
  let rSum: number = 0;
  let gSum: number = 0;
  let bSum: number = 0;
  let count: number = 0;
  for (let i: number = 0; i < pixels.length; i += bytesPerPixel) {
    const alpha: number = pixels[i + 3];
    if (alpha < 16) {
      continue;
    }
    bSum += pixels[i];
    gSum += pixels[i + 1];
    rSum += pixels[i + 2];
    count++;
  }
  if (count === 0) {
    return '#808080';
  }
  const r: number = Math.round(rSum / count);
  const g: number = Math.round(gSum / count);
  const b: number = Math.round(bSum / count);
  const clampR: number = Math.max(0, Math.min(255, r));
  const clampG: number = Math.max(0, Math.min(255, g));
  const clampB: number = Math.max(0, Math.min(255, b));
  const rText: string = clampR.toString(16);
  const gText: string = clampG.toString(16);
  const bText: string = clampB.toString(16);
  const rHex: string = rText.length === 1 ? `0${rText}` : rText;
  const gHex: string = gText.length === 1 ? `0${gText}` : gText;
  const bHex: string = bText.length === 1 ? `0${bText}` : bText;
  return `#${rHex}${gHex}${bHex}`;
}
