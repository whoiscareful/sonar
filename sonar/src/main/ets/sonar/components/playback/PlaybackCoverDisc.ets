import { image } from '@kit.ImageKit';
import { CoverCache } from '../../playback/CoverCache';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { LoadingIcon } from '../feedback/LoadingIcon';

/** 约 60fps 更新角度，便于暂停时冻结当前朝向（animateTo 无法保留中间角度） */
const COVER_ROTATION_TICK_MS: number = 16;

/** miniBar 因 Tab 切换重建时保留封面旋转角 */
let persistedCoverRotateDeg: number = 0;

@Component
export struct PlaybackCoverDisc {
  @Prop discSize: number = 44;
  @Prop @Watch('onCoverInputsChange') coverArtId: string = '';
  @Prop @Watch('onCoverInputsChange') coverRevision: number = 0;
  @Prop @Watch('onCoverInputsChange') trackId: string = '';
  @Prop @Watch('onSpinInputsChange') loading: boolean = false;
  @Prop @Watch('onSpinInputsChange') spinning: boolean = false;
  @Prop @Watch('onCoverInputsChange') showCover: boolean = false;
  @Prop idleIconColor: ResourceColor = UiTokens.COLOR_TAB_ICON_INACTIVE_ON_LIGHT_BG;

  @State private coverRotateDeg: number = 0;
  @State private coverPixelMap: image.PixelMap | null = null;
  @State private boundCoverArtId: string = '';
  private lastSpinning: boolean = false;
  private lastCoverRevision: number = -1;
  private lastTrackId: string = '';
  private rotationTimerId: number = -1;

  aboutToAppear(): void {
    this.coverRotateDeg = persistedCoverRotateDeg;
    this.lastCoverRevision = this.coverRevision;
    this.lastTrackId = this.trackId;
    this.syncCoverPixelMap(true);
    this.lastSpinning = this.shouldSpin();
    this.applySpinMotion(this.lastSpinning);
  }

  aboutToDisappear(): void {
    persistedCoverRotateDeg = this.coverRotateDeg;
    this.stopRotationTimer();
  }

  private onCoverInputsChange(): void {
    const revisionChanged: boolean = this.coverRevision !== this.lastCoverRevision;
    if (revisionChanged) {
      this.lastCoverRevision = this.coverRevision;
    }
    const trackIdChanged: boolean = this.trackId !== this.lastTrackId;
    if (trackIdChanged) {
      this.lastTrackId = this.trackId;
      this.resetCoverRotation();
    }
    const artId: string = this.showCover ? this.coverArtId : '';
    const artIdChanged: boolean = artId !== this.boundCoverArtId;
    this.syncCoverPixelMap(revisionChanged || artIdChanged);
  }

  private resetCoverRotation(): void {
    this.coverRotateDeg = 0;
    persistedCoverRotateDeg = 0;
  }

  private onSpinInputsChange(): void {
    const shouldSpin: boolean = this.shouldSpin();
    if (shouldSpin === this.lastSpinning) {
      return;
    }
    this.lastSpinning = shouldSpin;
    this.applySpinMotion(shouldSpin);
  }

  private shouldSpin(): boolean {
    return this.spinning && !this.loading;
  }

  private syncCoverPixelMap(force: boolean): void {
    const artId: string = this.showCover ? this.coverArtId : '';
    const nextMap: image.PixelMap | null = CoverCache.getDisplaySource(artId).pixelMap;
    if (!force && artId === this.boundCoverArtId && nextMap === this.coverPixelMap) {
      return;
    }
    this.boundCoverArtId = artId;
    this.coverPixelMap = nextMap;
    if (nextMap === null && artId.length > 0) {
      void CoverCache.load(artId).then((loaded: image.PixelMap | null) => {
        const currentArtId: string = this.showCover ? this.coverArtId : '';
        if (currentArtId !== artId || loaded === null) {
          return;
        }
        this.boundCoverArtId = artId;
        this.coverPixelMap = loaded;
      });
    }
  }

  private rotationStepDeg(): number {
    return 360 * COVER_ROTATION_TICK_MS / UiTokens.DOCK_COVER_ROTATION_DURATION;
  }

  private applySpinMotion(shouldSpin: boolean): void {
    if (shouldSpin) {
      this.startRotationTimer();
      return;
    }
    this.stopRotationTimer();
  }

  private startRotationTimer(): void {
    if (this.rotationTimerId >= 0) {
      return;
    }
    const stepDeg: number = this.rotationStepDeg();
    this.rotationTimerId = setInterval(() => {
      this.coverRotateDeg = this.coverRotateDeg + stepDeg;
    }, COVER_ROTATION_TICK_MS);
  }

  private stopRotationTimer(): void {
    if (this.rotationTimerId < 0) {
      return;
    }
    clearInterval(this.rotationTimerId);
    this.rotationTimerId = -1;
  }

  private idleIconSize(): number {
    return this.discSize > 0 ? Math.floor(this.discSize * 0.52) : 22;
  }

  private loadingIconSize(): number {
    return this.discSize > 0 ? Math.floor(this.discSize * 0.5) : 22;
  }

  @Builder
  private placeholderIcon() {
    Image($r('app.media.dock_music_note'))
      .width(this.idleIconSize())
      .height(this.idleIconSize())
      .fillColor(this.idleIconColor)
      .objectFit(ImageFit.Contain)
      .animation({ duration: 280, curve: Curve.EaseInOut })
  }

  @Builder
  private loadingOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(this.discSize)
        .height(this.discSize)
        .borderRadius(this.discSize / 2)
        .backgroundColor(UiTokens.COLOR_OVERLAY_SCRIM)
      LoadingIcon({
        iconSize: this.loadingIconSize(),
        color: UiTokens.COLOR_TEXT_ON_BRAND
      })
    }
    .width(this.discSize)
    .height(this.discSize)
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.showCover && this.coverPixelMap !== null) {
        Image(this.coverPixelMap)
          .width(this.discSize)
          .height(this.discSize)
          .borderRadius(this.discSize / 2)
          .objectFit(ImageFit.Cover)
          .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
          .clip(true)
          .rotate({
            x: 0,
            y: 0,
            z: 1,
            angle: this.coverRotateDeg,
            centerX: '50%',
            centerY: '50%'
          })
      } else {
        this.placeholderIcon()
      }

      if (this.loading) {
        this.loadingOverlay()
      }
    }
    .width(this.discSize)
    .height(this.discSize)
    .borderRadius(this.discSize / 2)
    .clip(true)
  }
}
