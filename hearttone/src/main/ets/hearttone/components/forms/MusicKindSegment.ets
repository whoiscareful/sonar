import { MusicListKind } from '../../api/SubsonicTypes';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

export const MUSIC_KIND_INDEX_FAVORITE: number = 0;
export const MUSIC_KIND_INDEX_RANDOM: number = 1;
export const MUSIC_KIND_INDEX_FREQUENT: number = 2;
export const MUSIC_KIND_INDEX_RECENT: number = 3;
export const MUSIC_KIND_INDEX_NEWEST: number = 4;

const REFRESH_ICON_SLIDE_MS: number = 200;
const REFRESH_ICON_SLIDE_X: number = -2;
const RANDOM_LABEL_SHIFT_X: number = -2;

export function musicKindFromIndex(index: number): MusicListKind {
  if (index === MUSIC_KIND_INDEX_FAVORITE) {
    return 'favorite';
  }
  if (index === MUSIC_KIND_INDEX_FREQUENT) {
    return 'frequent';
  }
  if (index === MUSIC_KIND_INDEX_RECENT) {
    return 'recent';
  }
  if (index === MUSIC_KIND_INDEX_NEWEST) {
    return 'newest';
  }
  return 'random';
}

export function musicKindToIndex(kind: MusicListKind): number {
  if (kind === 'favorite') {
    return MUSIC_KIND_INDEX_FAVORITE;
  }
  if (kind === 'frequent') {
    return MUSIC_KIND_INDEX_FREQUENT;
  }
  if (kind === 'recent') {
    return MUSIC_KIND_INDEX_RECENT;
  }
  if (kind === 'newest') {
    return MUSIC_KIND_INDEX_NEWEST;
  }
  return MUSIC_KIND_INDEX_RANDOM;
}

@Component
export struct MusicKindSegment {
  @Prop selectedIndex: number = 0;
  @Prop refreshSpinDeg: number = 0;
  @BuilderParam onSelect: (index: number) => void;

  private isRandomSelected(): boolean {
    return this.selectedIndex === MUSIC_KIND_INDEX_RANDOM;
  }

  private emitSelect(index: number): void {
    if (this.onSelect !== undefined) {
      this.onSelect(index);
    }
  }

  @Builder
  segmentItem(label: string, index: number) {
    Text(label)
      .width('100%')
      .textAlign(TextAlign.Center)
      .fontSize(14)
      .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selectedIndex === index ?
        UiTokens.COLOR_TEXT_PRIMARY : UiTokens.COLOR_TEXT_SECONDARY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ top: 8, bottom: 8 })
      .borderRadius(10)
      .backgroundColor(this.selectedIndex === index ? UiTokens.COLOR_PRIMARY_SOFT_BG : Color.Transparent)
      .onClick(() => {
        this.emitSelect(index);
      })
  }

  @Builder
  randomSegmentItem() {
    Row({ space: 4 }) {
      Text('随机')
        .fontSize(14)
        .fontWeight(this.isRandomSelected() ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.isRandomSelected() ?
          UiTokens.COLOR_TEXT_PRIMARY : UiTokens.COLOR_TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .flexShrink(1)
        .translate({ x: this.isRandomSelected() ? RANDOM_LABEL_SHIFT_X : 0 })
        .animation({ duration: REFRESH_ICON_SLIDE_MS, curve: Curve.EaseOut })
      if (this.isRandomSelected()) {
        Image($r('app.media.ic_refresh_rounded'))
          .width(17)
          .height(17)
          .fillColor(UiTokens.COLOR_TEXT_TERTIARY)
          .flexShrink(0)
          .rotate({ angle: this.refreshSpinDeg })
          .transition(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ x: REFRESH_ICON_SLIDE_X }))
              .animation({ duration: REFRESH_ICON_SLIDE_MS, curve: Curve.EaseOut })
          )
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .clip(true)
    .padding({ top: 8, bottom: 8 })
    .borderRadius(10)
    .backgroundColor(this.isRandomSelected() ? UiTokens.COLOR_PRIMARY_SOFT_BG : Color.Transparent)
    .onClick(() => {
      this.emitSelect(MUSIC_KIND_INDEX_RANDOM);
    })
    .accessibilityText(this.isRandomSelected() ? '随机，再次点击刷新' : '随机')
  }

  build() {
    Row() {
      Column() {
        this.segmentItem('歌单', MUSIC_KIND_INDEX_FAVORITE)
      }
      .layoutWeight(1)

      Column() {
        this.randomSegmentItem()
      }
      .layoutWeight(1)

      Column() {
        this.segmentItem('常听', MUSIC_KIND_INDEX_FREQUENT)
      }
      .layoutWeight(1)

      Column() {
        this.segmentItem('最近', MUSIC_KIND_INDEX_RECENT)
      }
      .layoutWeight(1)

      Column() {
        this.segmentItem('新增', MUSIC_KIND_INDEX_NEWEST)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(4)
    .borderRadius(12)
    .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
    .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
    .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
  }
}
