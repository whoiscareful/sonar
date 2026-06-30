@Component
export struct AutoMarqueeText {
  @Prop @Watch('onMarqueeContentChange') text: string = '';
  @Prop fontSize: number = 15;
  @Prop fontColor: ResourceColor = Color.Black;
  @Prop fontWeight: FontWeight = FontWeight.Regular;
  @Prop @Watch('onMarqueeContentChange') secondaryText: string = '';
  @Prop secondaryFontSize: number = 11;
  @Prop secondaryFontColor: ResourceColor = Color.Black;
  @Prop secondaryFontWeight: FontWeight = FontWeight.Regular;
  @Prop secondaryGapVp: number = 6;
  @Prop edgeFadeRatio: number = 0.08;
  @Prop enableEdgeFade: boolean = true;
  @State private _contentWidthVp: number = 0;
  @State private _enableEdgeFade: boolean = false;

  private hasSecondaryText(): boolean {
    return this.secondaryText.length > 0;
  }

  private normalizedFadeRatio(): number {
    return Math.max(0.02, Math.min(0.2, this.edgeFadeRatio));
  }

  private edgeFadeGradientColors(): Array<[ResourceColor, number]> {
    const fade: number = this.normalizedFadeRatio();
    return [
      ['rgba(0, 0, 0, 0)', 0.0],
      ['rgba(0, 0, 0, 1)', fade],
      ['rgba(0, 0, 0, 1)', 1.0 - fade],
      ['rgba(0, 0, 0, 0)', 1.0]
    ];
  }

  private resolveVpLength(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      if (value.endsWith('vp')) {
        return Number.parseFloat(value);
      }
      if (value.endsWith('px')) {
        return this.getUIContext().px2vp(Number.parseFloat(value));
      }
      const parsed: number = Number.parseFloat(value);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
    return 0;
  }

  private measureTextWidthPx(content: string, sizeVp: number, weight: FontWeight): number {
    if (content.length === 0) {
      return 0;
    }
    return this.getUIContext().getMeasureUtils().measureText({
      textContent: content,
      fontSize: `${sizeVp}vp`,
      fontWeight: weight
    });
  }

  private measureContentWidthPx(): number {
    const titleWidthPx: number = this.measureTextWidthPx(this.text, this.fontSize, this.fontWeight);
    if (!this.hasSecondaryText()) {
      return titleWidthPx;
    }
    const gapPx: number = this.getUIContext().vp2px(Math.max(0, this.secondaryGapVp));
    const secondaryWidthPx: number = this.measureTextWidthPx(
      this.secondaryText, this.secondaryFontSize, this.secondaryFontWeight);
    return titleWidthPx + gapPx + secondaryWidthPx;
  }

  private updateEdgeFade(): void {
    const widthVp: number = Math.max(0, this._contentWidthVp);
    if (widthVp <= 0 || (this.text.length === 0 && !this.hasSecondaryText())) {
      this._enableEdgeFade = false;
      return;
    }
    try {
      const textWidthPx: number = this.measureContentWidthPx();
      const containerWidthPx: number = this.getUIContext().vp2px(widthVp);
      const enableThresholdPx: number = 3;
      const disableThresholdPx: number = 1;
      if (this._enableEdgeFade) {
        this._enableEdgeFade = textWidthPx > containerWidthPx + disableThresholdPx;
      } else {
        this._enableEdgeFade = textWidthPx > containerWidthPx + enableThresholdPx;
      }
    } catch (_e) {
      this._enableEdgeFade = false;
    }
  }

  aboutToAppear(): void {
    this.updateEdgeFade();
  }

  private onMarqueeContentChange(): void {
    this.updateEdgeFade();
  }

  @Builder
  private buildMarqueeText() {
    if (this.hasSecondaryText()) {
      Text() {
        Span(this.text)
          .fontSize(this.fontSize)
          .fontWeight(this.fontWeight)
          .fontColor(this.fontColor)
        Span(' ')
          .fontSize(this.fontSize)
          .letterSpacing(this.secondaryGapVp)
        Span(this.secondaryText)
          .fontSize(this.secondaryFontSize)
          .fontWeight(this.secondaryFontWeight)
          .fontColor(this.secondaryFontColor)
      }
      .width('100%')
      .textOverflow({ overflow: TextOverflow.MARQUEE })
      .textAlign(TextAlign.Start)
      .clip(true)
    } else {
      Text(this.text)
        .fontSize(this.fontSize)
        .fontWeight(this.fontWeight)
        .fontColor(this.fontColor)
        .width('100%')
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .textAlign(TextAlign.Start)
        .clip(true)
    }
  }

  @Builder
  private buildMarqueeWithEdgeFade() {
    Row() {
      Column() {
        this.buildMarqueeText()
      }
      .width('100%')
      .height('100%')
      .blendMode(BlendMode.SRC_IN, BlendApplyType.OFFSCREEN)
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 90,
      colors: this.edgeFadeGradientColors()
    })
    .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
    .clip(true)
  }

  build() {
    Column() {
      if (this.enableEdgeFade && this._enableEdgeFade) {
        this.buildMarqueeWithEdgeFade()
      } else {
        this.buildMarqueeText()
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .onAreaChange((_oldValue, newValue) => {
      const nextWidthVp: number = this.resolveVpLength(newValue.width);
      if (Math.abs(nextWidthVp - this._contentWidthVp) > 0.5) {
        this._contentWidthVp = nextWidthVp;
        this.updateEdgeFade();
      }
    })
  }
}
