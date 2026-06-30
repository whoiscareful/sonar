import { AutoCacheMode, CacheLimitGb } from '../cache/SongCacheTypes';
import { CoverCache } from '../playback/CoverCache';
import { CoverCacheSettingsStore } from '../cache/CoverCacheSettingsStore';
import { CoverCacheStore } from '../cache/CoverCacheStore';
import { SongCache } from '../cache/SongCache';
import { SongCacheSettingsStore } from '../cache/SongCacheSettingsStore';
import { SongCacheStore } from '../cache/SongCacheStore';
import { CardContainer } from '../components/layout/CardContainer';
import { UiTokens } from '../ui/tokens/UiTokens';

interface SelectOption {
  value: string;
}

@Component
export struct CacheSettingsPage {
  @StorageLink('songCacheUsedBytes') songCacheUsedBytes: number = 0;
  @StorageLink('songCacheLimitGb') songCacheLimitGb: number = 2;
  @StorageLink('songCacheAutoMode') songCacheAutoMode: string = 'wifi_only';
  @StorageLink('coverCacheUsedBytes') coverCacheUsedBytes: number = 0;
  @StorageLink('coverCacheLimitGb') coverCacheLimitGb: number = 2;
  @StorageLink('coverCacheAutoMode') coverCacheAutoMode: string = 'wifi_only';

  private readonly autoCacheOptions: SelectOption[] = [
    { value: '关闭' },
    { value: '开启' },
    { value: '仅在 WiFi 下开启' }
  ];

  private readonly limitOptions: SelectOption[] = [
    { value: '1 GB' },
    { value: '2 GB' },
    { value: '5 GB' },
    { value: '10 GB' }
  ];

  private autoCacheSelectIndex(mode: string): number {
    if (mode === 'off') {
      return 0;
    }
    if (mode === 'always') {
      return 1;
    }
    return 2;
  }

  private limitSelectIndex(limitGb: number): number {
    if (limitGb === 1) {
      return 0;
    }
    if (limitGb === 2) {
      return 1;
    }
    if (limitGb === 5) {
      return 2;
    }
    return 3;
  }

  private async onSongAutoCacheSelect(index: number): Promise<void> {
    let mode: AutoCacheMode = 'wifi_only';
    if (index === 0) {
      mode = 'off';
    } else if (index === 1) {
      mode = 'always';
    }
    await SongCacheSettingsStore.getInstance().setAutoCacheMode(mode);
  }

  private async onSongLimitSelect(index: number): Promise<void> {
    const limits: CacheLimitGb[] = [1, 2, 5, 10];
    const nextLimit: CacheLimitGb = limits[index] ?? 2;
    await SongCacheSettingsStore.getInstance().setLimitGb(nextLimit);
    await SongCache.evictIfNeeded();
  }

  private async onCoverAutoCacheSelect(index: number): Promise<void> {
    let mode: AutoCacheMode = 'wifi_only';
    if (index === 0) {
      mode = 'off';
    } else if (index === 1) {
      mode = 'always';
    }
    await CoverCacheSettingsStore.getInstance().setAutoCacheMode(mode);
  }

  private async onCoverLimitSelect(index: number): Promise<void> {
    const limits: CacheLimitGb[] = [1, 2, 5, 10];
    const nextLimit: CacheLimitGb = limits[index] ?? 2;
    await CoverCacheSettingsStore.getInstance().setLimitGb(nextLimit);
    await CoverCache.evictIfNeeded();
  }

  @Builder
  private buildSectionTitle(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
      .width('100%')
      .alignSelf(ItemAlign.Start)
  }

  @Builder
  private buildAutoCacheRow(title: string, subtitle: string, mode: string, onSelect: (index: number) => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(subtitle)
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Select(this.autoCacheOptions)
        .selected(this.autoCacheSelectIndex(mode))
        .value(this.autoCacheOptions[this.autoCacheSelectIndex(mode)].value)
        .font({ size: 14 })
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .selectedOptionFont({ size: 14, weight: FontWeight.Medium })
        .optionFont({ size: 14 })
        .onSelect((index: number) => {
          onSelect(index);
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildLimitRow(usedBytes: number, limitGb: number, onSelect: (index: number) => void) {
    Row() {
      Column({ space: 4 }) {
        Text('缓存上限')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(`已用 ${SongCacheStore.formatBytes(usedBytes)} / ${limitGb} GB`)
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Select(this.limitOptions)
        .selected(this.limitSelectIndex(limitGb))
        .value(this.limitOptions[this.limitSelectIndex(limitGb)].value)
        .font({ size: 14 })
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .selectedOptionFont({ size: 14, weight: FontWeight.Medium })
        .optionFont({ size: 14 })
        .onSelect((index: number) => {
          onSelect(index);
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column({ space: UiTokens.SECTION_GAP }) {
      this.buildSectionTitle('音乐缓存')

      CardContainer() {
        Column({ space: 16 }) {
          this.buildAutoCacheRow(
            '边听边下',
            '听歌时自动缓存到本地',
            this.songCacheAutoMode,
            (index: number): void => {
              void this.onSongAutoCacheSelect(index);
            }
          )
          this.buildLimitRow(
            this.songCacheUsedBytes,
            this.songCacheLimitGb,
            (index: number): void => {
              void this.onSongLimitSelect(index);
            }
          )
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      this.buildSectionTitle('专辑图片缓存')

      CardContainer() {
        Column({ space: 16 }) {
          this.buildAutoCacheRow(
            '缓存图片',
            '浏览曲库与专辑时自动缓存封面',
            this.coverCacheAutoMode,
            (index: number): void => {
              void this.onCoverAutoCacheSelect(index);
            }
          )
          this.buildLimitRow(
            this.coverCacheUsedBytes,
            this.coverCacheLimitGb,
            (index: number): void => {
              void this.onCoverLimitSelect(index);
            }
          )
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
