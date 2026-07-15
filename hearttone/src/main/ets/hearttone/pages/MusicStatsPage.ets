import { Song } from '../api/SubsonicTypes';
import { AuthStore, SavedAuth } from '../auth/AuthStore';
import { SongMetadataCache } from '../cache/SongMetadataCache';
import { CardContainer } from '../components/layout/CardContainer';
import { MusicTagWebStats } from '../enhanced/MusicTagWebOpenApi';
import { MusicTagWebOpenApiClient } from '../enhanced/MusicTagWebOpenApiClient';
import { OpenApiCredentialStore } from '../enhanced/OpenApiCredentialStore';
import { ListeningEvent, RecentPlayHistoryStore } from '../settings/RecentPlayHistoryStore';
import { UiTokens } from '../ui/tokens/UiTokens';

interface DailyListeningStat {
  timestamp: number;
  label: string;
  count: number;
  durationSec: number;
}

interface ArtistListeningStat {
  name: string;
  count: number;
  durationSec: number;
}

const WEEKDAY_LABELS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

@Component
export struct MusicStatsPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State private periodDays: number = 7;
  @State private loading: boolean = true;
  @State private serverLoading: boolean = false;
  @State private errorMessage: string = '';
  @State private allEvents: ListeningEvent[] = [];
  @State private dailyStats: DailyListeningStat[] = [];
  @State private topArtists: ArtistListeningStat[] = [];
  @State private totalPlays: number = 0;
  @State private totalDurationSec: number = 0;
  @State private uniqueSongCount: number = 0;
  @State private serverStats: MusicTagWebStats | null = null;
  @State private hasOpenApiToken: boolean = false;
  @State private serverError: string = '';

  aboutToAppear(): void {
    void this.loadAll();
  }

  private async loadAll(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const history: RecentPlayHistoryStore = RecentPlayHistoryStore.getInstance();
      await history.ensureReady();
      const events: ListeningEvent[] = history.listListeningEvents(90);
      this.allEvents = await this.enrichLegacyEvents(events);
      this.rebuildListeningStats();
    } catch (err) {
      this.errorMessage = (err as Error).message || '听歌数据读取失败';
    } finally {
      this.loading = false;
    }
    await this.loadServerStats();
  }

  private async enrichLegacyEvents(events: ListeningEvent[]): Promise<ListeningEvent[]> {
    const missingIds: string[] = [];
    const seen: Set<string> = new Set<string>();
    for (let i: number = 0; i < events.length; i++) {
      const event: ListeningEvent = events[i];
      if ((event.title.length === 0 || event.artist.length === 0 || event.durationSec <= 0) &&
        !seen.has(event.songId)) {
        seen.add(event.songId);
        missingIds.push(event.songId);
      }
    }
    if (missingIds.length === 0) {
      return events;
    }
    const songs: Song[] = await SongMetadataCache.getMany(missingIds);
    const songMap: Map<string, Song> = new Map<string, Song>();
    for (let i: number = 0; i < songs.length; i++) {
      songMap.set(songs[i].id, songs[i]);
    }
    return events.map((event: ListeningEvent) => {
      const song: Song | undefined = songMap.get(event.songId);
      if (song === undefined) {
        return event;
      }
      return {
        songId: event.songId,
        title: event.title.length > 0 ? event.title : song.title,
        artist: event.artist.length > 0 ? event.artist : song.artist,
        durationSec: event.durationSec > 0 ? event.durationSec : song.duration,
        playedAt: event.playedAt
      };
    });
  }

  private async loadServerStats(): Promise<void> {
    this.serverLoading = true;
    this.serverError = '';
    const token: string = await OpenApiCredentialStore.getToken();
    this.hasOpenApiToken = token.length > 0;
    if (!this.hasOpenApiToken) {
      this.serverStats = null;
      this.serverLoading = false;
      return;
    }
    try {
      const auth: SavedAuth | null = AuthStore.getInstance().getCredentials();
      this.serverStats = await MusicTagWebOpenApiClient.getInstance().stats(auth?.username,
        'album_count,track_count,artist_count,song_size,song_duration,now_playing');
    } catch (err) {
      this.serverStats = null;
      this.serverError = (err as Error).message || '曲库统计读取失败';
    } finally {
      this.serverLoading = false;
    }
  }

  private selectPeriod(days: number): void {
    if (this.periodDays === days) {
      return;
    }
    this.periodDays = days;
    this.rebuildListeningStats();
  }

  private rebuildListeningStats(): void {
    const now: Date = new Date();
    const todayStart: Date = new Date(now.getTime());
    todayStart.setHours(0, 0, 0, 0);
    const firstDayMs: number = todayStart.getTime() - (this.periodDays - 1) * 24 * 60 * 60 * 1000;
    const selected: ListeningEvent[] = this.allEvents.filter((event: ListeningEvent) => event.playedAt >= firstDayMs);
    this.totalPlays = selected.length;
    this.totalDurationSec = 0;
    const songIds: Set<string> = new Set<string>();
    const artistCount: Map<string, number> = new Map<string, number>();
    const artistDuration: Map<string, number> = new Map<string, number>();
    for (let i: number = 0; i < selected.length; i++) {
      const event: ListeningEvent = selected[i];
      this.totalDurationSec += Math.max(0, event.durationSec);
      songIds.add(event.songId);
      const artist: string = event.artist.length > 0 ? event.artist : '未知歌手';
      artistCount.set(artist, (artistCount.get(artist) ?? 0) + 1);
      artistDuration.set(artist, (artistDuration.get(artist) ?? 0) + Math.max(0, event.durationSec));
    }
    this.uniqueSongCount = songIds.size;

    const days: DailyListeningStat[] = [];
    for (let index: number = 0; index < this.periodDays; index++) {
      const timestamp: number = firstDayMs + index * 24 * 60 * 60 * 1000;
      const date: Date = new Date(timestamp);
      days.push({
        timestamp: timestamp,
        label: this.periodDays === 7 ?
          (index === this.periodDays - 1 ? '今天' : `周${WEEKDAY_LABELS[date.getDay()]}`) :
          (index === this.periodDays - 1 ? '今天' : (index % 5 === 0 ? `${date.getMonth() + 1}/${date.getDate()}` : '')),
        count: 0,
        durationSec: 0
      });
    }
    for (let i: number = 0; i < selected.length; i++) {
      const event: ListeningEvent = selected[i];
      const dayIndex: number = Math.floor((event.playedAt - firstDayMs) / (24 * 60 * 60 * 1000));
      if (dayIndex >= 0 && dayIndex < days.length) {
        days[dayIndex].count += 1;
        days[dayIndex].durationSec += Math.max(0, event.durationSec);
      }
    }
    this.dailyStats = days;

    const artists: ArtistListeningStat[] = [];
    artistCount.forEach((count: number, name: string) => {
      artists.push({ name: name, count: count, durationSec: artistDuration.get(name) ?? 0 });
    });
    artists.sort((left: ArtistListeningStat, right: ArtistListeningStat) => right.count - left.count);
    this.topArtists = artists.slice(0, 5);
  }

  private maxDailyCount(): number {
    let maxCount: number = 1;
    for (let i: number = 0; i < this.dailyStats.length; i++) {
      maxCount = Math.max(maxCount, this.dailyStats[i].count);
    }
    return maxCount;
  }

  private formatDuration(seconds: number): string {
    const minutes: number = Math.floor(Math.max(0, seconds) / 60);
    if (minutes < 60) {
      return `${minutes} 分钟`;
    }
    const hours: number = Math.floor(minutes / 60);
    const remainingMinutes: number = minutes % 60;
    return remainingMinutes > 0 ? `${hours} 小时 ${remainingMinutes} 分` : `${hours} 小时`;
  }

  @Builder
  private periodOption(label: string, days: number) {
    Text(label)
      .layoutWeight(1)
      .height(32)
      .textAlign(TextAlign.Center)
      .fontSize(12)
      .fontWeight(this.periodDays === days ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.periodDays === days ? UiTokens.COLOR_TEXT_ON_BRAND : UiTokens.COLOR_TEXT_SECONDARY)
      .backgroundColor(this.periodDays === days ? UiTokens.COLOR_PRIMARY : Color.Transparent)
      .borderRadius(9)
      .onClick(() => {
        this.selectPeriod(days);
      })
  }

  @Builder
  private summaryMetric(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label)
        .fontSize(10)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private dailyBar(item: DailyListeningStat, maxCount: number) {
    Column({ space: 5 }) {
      Text(item.count > 0 ? `${item.count}` : '')
        .height(16)
        .fontSize(9)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      Column()
        .width(14)
        .height(item.count > 0 ? 12 + Math.floor(item.count * 72 / maxCount) : 4)
        .borderRadius(5)
        .backgroundColor(item.count > 0 ? UiTokens.COLOR_PRIMARY : UiTokens.COLOR_CARD_BORDER)
      Text(item.label)
        .fontSize(this.periodDays === 7 ? 9 : 7)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(116)
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private serverMetric(label: string, value: string | undefined) {
    Column({ space: 3 }) {
      Text(value ?? '-')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label)
        .fontSize(10)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private listeningOverview() {
    CardContainer() {
      Column({ space: 14 }) {
        Row() {
          Column({ space: 3 }) {
            Text('聆听概览')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text(`近 ${this.periodDays} 天`)
              .fontSize(11)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Row() {
            this.periodOption('7 天', 7)
            this.periodOption('30 天', 30)
          }
          .width(126)
          .padding(2)
          .borderRadius(11)
          .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          this.summaryMetric(`${this.totalPlays}`, '有效播放')
          this.summaryMetric(this.formatDuration(this.totalDurationSec), '聆听时长')
          this.summaryMetric(`${this.uniqueSongCount}`, '听过歌曲')
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private trendChart() {
    CardContainer() {
      Column({ space: 8 }) {
        Row() {
          Text('播放趋势')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Blank()
          Text('按有效播放次数')
            .fontSize(10)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
        }
        .width('100%')

        Row({ space: this.periodDays === 7 ? 6 : 1 }) {
          ForEach(this.dailyStats, (item: DailyListeningStat) => {
            this.dailyBar(item, this.maxDailyCount())
          }, (item: DailyListeningStat) => `${item.timestamp}`)
        }
        .width('100%')
        .height(116)
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private artistRanking() {
    CardContainer() {
      Column({ space: 13 }) {
        Text('常听歌手')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          .width('100%')
        if (this.topArtists.length === 0) {
          Text('这一时段还没有有效播放记录')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .width('100%')
            .padding({ top: 10, bottom: 10 })
        } else {
          ForEach(this.topArtists, (artist: ArtistListeningStat, index: number) => {
            Column({ space: 7 }) {
              Row({ space: 8 }) {
                Text(`${index + 1}`)
                  .width(20)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(UiTokens.COLOR_PRIMARY)
                Text(artist.name)
                  .layoutWeight(1)
                  .fontSize(13)
                  .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${artist.count} 次`)
                  .fontSize(11)
                  .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              }
              .width('100%')
              Row() {
                Column()
                  .width(`${Math.max(6, Math.floor(artist.count * 100 / this.topArtists[0].count))}%`)
                  .height(4)
                  .borderRadius(2)
                  .backgroundColor(index === 0 ? UiTokens.COLOR_PRIMARY : UiTokens.COLOR_INFO)
              }
              .width('100%')
              .height(4)
              .borderRadius(2)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            }
            .width('100%')
          }, (artist: ArtistListeningStat) => artist.name)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private libraryOverview() {
    CardContainer() {
      Column({ space: 13 }) {
        Row() {
          Column({ space: 3 }) {
            Text('曲库概览')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text(this.serverStats !== null ? 'Music Tag Web 已连接' : 'Music Tag Web')
              .fontSize(10)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          if (this.serverLoading) {
            LoadingProgress().width(18).height(18).color(UiTokens.COLOR_PRIMARY)
          } else {
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.ic_refresh_rounded'))
                .width(14)
                .height(14)
                .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
            }
            .width(30)
            .height(30)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .onClick(() => {
              void this.loadServerStats();
            })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.serverStats !== null) {
          Row() {
            this.serverMetric('专辑', this.serverStats.albumCount)
            this.serverMetric('歌曲', this.serverStats.trackCount)
            this.serverMetric('歌手', this.serverStats.artistCount)
          }
          .width('100%')
          Row({ space: 8 }) {
            Text(`容量 ${this.serverStats.songSize ?? '-'}`)
              .layoutWeight(1)
              .fontSize(11)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              .padding({ left: 9, right: 9, top: 7, bottom: 7 })
              .borderRadius(9)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            Text(`总时长 ${this.serverStats.songDuration ?? '-'}`)
              .layoutWeight(1)
              .fontSize(11)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              .padding({ left: 9, right: 9, top: 7, bottom: 7 })
              .borderRadius(9)
              .backgroundColor(UiTokens.COLOR_INFO_SOFT_BG)
          }
          .width('100%')
          if ((this.serverStats.nowPlaying ?? '').length > 0) {
            Text(`正在播放：${this.serverStats.nowPlaying ?? '-'}`)
              .width('100%')
              .fontSize(11)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        } else if (!this.hasOpenApiToken) {
          Row() {
            Text('尚未配置开放 API')
              .fontSize(12)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            Blank()
            Text('前往设置')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(UiTokens.COLOR_PRIMARY)
              .onClick(() => {
                this.appPathStack.pushPathByName('ServerPage', null);
              })
          }
          .width('100%')
        } else if (this.serverError.length > 0) {
          Text(this.serverError)
            .width('100%')
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .maxLines(2)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Column({ space: UiTokens.SECTION_GAP }) {
      if (this.loading) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color(UiTokens.COLOR_PRIMARY)
          Text('正在整理听歌数据')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .height(180)
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .width('100%')
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .padding(16)
      } else {
        this.listeningOverview()
        this.trendChart()
        this.artistRanking()
      }
      this.libraryOverview()
    }
    .width('100%')
  }
}
