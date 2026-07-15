import { Album, AlbumDetailRouteParam, Song } from '../api/SubsonicTypes';
import { CoverDisplayResolver } from '../cache/CoverDisplayResolver';
import { SuccessButton } from '../components/buttons/SuccessButton';
import { LoadingState } from '../components/feedback/LoadingState';
import { EmptyState } from '../components/feedback/EmptyState';
import { ErrorState } from '../components/feedback/ErrorState';
import { GlassSearchBar } from '../components/forms/GlassSearchBar';
import { AutoMarqueeText } from '../components/layout/AutoMarqueeText';
import { CardContainer } from '../components/layout/CardContainer';
import { GlobalPageBackground } from '../components/layout/GlobalPageBackground';
import { HeartTonePageLayout } from '../components/layout/HeartTonePageLayout';
import { ToastUtil } from '../common/ToastUtil';
import { PlaybackService } from '../playback/PlaybackService';
import { PlaybackSnapshot } from '../playback/PlaybackSnapshot';
import { LibraryViewModel, LibraryTab } from '../viewmodel/LibraryViewModel';
import { ImmersivePageOffsets } from '../ui/layout/ImmersivePageOffsets';
import { LibraryGridLayout } from '../ui/layout/LibraryGridLayout';
import { TabScrollerBridge } from '../ui/layout/TabScrollerBridge';
import { HeartTonePageRole, HeartToneScrollMode } from '../ui/layout/HeartTonePageLayoutOptions';
import { GlassSurfaceHelper } from '../ui/material/GlassSurfaceHelper';
import { UiTokens } from '../ui/tokens/UiTokens';
import { MusicCatalogRepository } from '../domain/music/MusicCatalogRepository';
import { OpenApiCredentialStore } from '../enhanced/OpenApiCredentialStore';

const DISCOVERY_SONG_COUNT: number = 60;

@Component
export struct LibraryPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Consume('tabScrollerBridge') tabScrollerBridge: TabScrollerBridge = new TabScrollerBridge();
  @StorageLink('authPhase') @Watch('onAuthSnapshotChanged') authPhase: string = 'booting';
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('rootTabActive') rootTabActive: boolean = false;
  @StorageLink('coverCacheRevision') coverCacheRevision: number = 0;
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @StorageLink('loggedInEndpoint') loggedInEndpoint: string = 'remote';
  @StorageLink('hasOpenApiToken') hasOpenApiToken: boolean = false;
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @State vm: LibraryViewModel = new LibraryViewModel();
  @State private searchKeyword: string = '';
  @State private gridColumns: number = UiTokens.LIBRARY_GRID_MIN_COLUMNS;
  @State private playActionLoading: boolean = false;
  private readonly catalog: MusicCatalogRepository = MusicCatalogRepository.getInstance();

  private showToast(message: string): void {
    ToastUtil.show(this, message, 1600);
  }

  private updateGridColumnsByWidth(widthVp: number): void {
    const nextColumns: number = LibraryGridLayout.resolveColumns(widthVp);
    if (nextColumns !== this.gridColumns) {
      this.gridColumns = nextColumns;
    }
  }

  private feedTitle(): string {
    if (this.vm.isSearchMode) {
      return `“${this.vm.searchQuery}”的搜索结果`;
    }
    if (this.vm.tab === 'frequent') {
      return '你的高频专辑';
    }
    if (this.vm.tab === 'random') {
      return '随机专辑漫游';
    }
    return '最近入库';
  }

  private feedSubtitle(): string {
    if (this.vm.isSearchMode) {
      return `${this.vm.albums.length} 个匹配结果`;
    }
    if (this.vm.tab === 'frequent') {
      return '由 Subsonic 播放频次生成';
    }
    if (this.vm.tab === 'random') {
      return '每次刷新都有不同发现';
    }
    return '来自你的 Subsonic 音乐库';
  }

  private submitSearch(): void {
    const keyword: string = this.searchKeyword.trim();
    if (keyword.length === 0) {
      if (this.vm.isSearchMode || this.vm.searchQuery.length > 0) {
        void this.vm.loadHome();
      }
      return;
    }
    if (this.vm.isSearchMode && keyword === this.vm.searchQuery) {
      return;
    }
    void this.vm.searchAlbums(keyword);
  }

  private selectFeed(tab: LibraryTab): void {
    this.searchKeyword = '';
    if (tab === 'frequent') {
      void this.vm.loadFrequent();
    } else if (tab === 'random') {
      void this.vm.loadRandom();
    } else {
      void this.vm.loadNewest();
    }
  }

  private retryLoad(): void {
    if (this.vm.isSearchMode) {
      void this.vm.searchAlbums(this.vm.searchQuery);
    } else {
      this.selectFeed(this.vm.tab);
    }
  }

  private openAlbum(album: Album): void {
    const routeParam: AlbumDetailRouteParam = { albumId: album.id };
    this.appPathStack.pushPathByName('AlbumDetailPage', routeParam);
  }

  private async playAlbum(album: Album): Promise<void> {
    if (this.playActionLoading) {
      return;
    }
    this.playActionLoading = true;
    try {
      await PlaybackService.playAlbumAll(album);
      PlaybackService.setPlaybackMode('listLoop');
    } catch (err) {
      const message: string = (err as Error).message;
      this.showToast(message === 'EMPTY_ALBUM' ? '这张专辑暂时没有曲目' : (message || '播放失败'));
    } finally {
      this.playActionLoading = false;
    }
  }

  private async startSonicDiscovery(): Promise<void> {
    if (this.playActionLoading) {
      return;
    }
    this.playActionLoading = true;
    try {
      const songs: Song[] = await this.catalog.randomSongs(DISCOVERY_SONG_COUNT);
      if (songs.length === 0) {
        this.showToast('音乐库中暂时没有可播放曲目');
        return;
      }
      await PlaybackService.playQueue(songs, 0);
      PlaybackService.setPlaybackMode('random');
      this.showToast(`已生成 ${songs.length} 首随机声波`);
    } catch (err) {
      this.showToast((err as Error).message || '随机发现失败');
    } finally {
      this.playActionLoading = false;
    }
  }

  private hasOpenApiStats(): boolean {
    return this.vm.openApiStats !== null &&
      (this.vm.openApiStats.albumCount !== undefined ||
        this.vm.openApiStats.trackCount !== undefined ||
        this.vm.openApiStats.artistCount !== undefined);
  }

  private statText(label: string, value: string | undefined): string {
    return `${value ?? '-'} ${label}`;
  }

  @Builder
  private apiMetric(label: string, value: string | undefined) {
    Column({ space: 3 }) {
      Text(value ?? '-')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
      Text(label)
        .fontSize(10)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private musicTagWebPanel() {
    CardContainer() {
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Column()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor(this.vm.openApiStats !== null ? UiTokens.COLOR_SUCCESS : UiTokens.COLOR_TEXT_TERTIARY)
          Column({ space: 2 }) {
            Text('Music Tag Web')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text(this.vm.openApiStats !== null ? '开放 API 已连接' : '开放 API 数据面板')
              .fontSize(10)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          if (this.vm.openApiStatsLoading) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color(UiTokens.COLOR_PRIMARY)
          } else {
            Text('刷新')
              .fontSize(12)
              .fontColor(UiTokens.COLOR_PRIMARY)
              .padding({ left: 10, right: 10, top: 7, bottom: 7 })
              .onClick(() => {
                void this.vm.loadOpenApiStats();
              })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.vm.openApiStats !== null) {
          Row() {
            this.apiMetric('专辑', this.vm.openApiStats.albumCount)
            this.apiMetric('歌曲', this.vm.openApiStats.trackCount)
            this.apiMetric('歌手', this.vm.openApiStats.artistCount)
          }
          .width('100%')

          Row({ space: 8 }) {
            Text(`容量 ${this.vm.openApiStats.songSize ?? '-'}`)
              .fontSize(11)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .borderRadius(12)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            Text(`总时长 ${this.vm.openApiStats.songDuration ?? '-'}`)
              .fontSize(11)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .borderRadius(12)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
          }
          .width('100%')

          if ((this.vm.openApiStats.nowPlaying ?? '').length > 0) {
            Column({ space: 3 }) {
              Text('服务端正在播放')
                .fontSize(10)
                .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
              Text(this.vm.openApiStats.nowPlaying ?? '-')
                .fontSize(12)
                .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        } else if (this.vm.openApiStatsError.length > 0) {
          Text(`暂时无法读取：${this.vm.openApiStatsError}`)
            .width('100%')
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .maxLines(2)
        } else {
          Text('正在读取 Music Tag Web 数据…')
            .width('100%')
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private apiMetricTile(label: string, value: string | undefined) {
    Column({ space: 2 }) {
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
    .height(48)
    .padding({ left: 9, right: 9, top: 7, bottom: 6 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .borderRadius(10)
    .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
    .border({ width: 1, color: UiTokens.COLOR_CARD_BORDER })
  }

  @Builder
  private apiInfoChip(label: string, value: string | undefined) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(10)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      Text(value ?? '-')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(25)
    .padding({ left: 8, right: 8 })
    .alignItems(VerticalAlign.Center)
    .borderRadius(9)
    .backgroundColor(UiTokens.COLOR_CARD_BG)
    .border({ width: 1, color: UiTokens.COLOR_CARD_BORDER })
  }

  @Builder
  private musicTagWebPanelV2() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(76)
        .height(76)
        .borderRadius(38)
        .backgroundColor(UiTokens.COLOR_INFO_SOFT_BG)
        .blur(22)
        .translate({ x: 246, y: -36 })

      Column({ space: 9 }) {
        Row({ space: 8 }) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(30)
              .height(30)
              .borderRadius(10)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            Column()
              .width(10)
              .height(10)
              .borderRadius(5)
              .backgroundColor(this.vm.openApiStats !== null ? UiTokens.COLOR_SUCCESS : UiTokens.COLOR_TEXT_TERTIARY)
            Column()
              .width(20)
              .height(20)
              .borderRadius(10)
              .border({ width: 1, color: this.vm.openApiStats !== null ? UiTokens.COLOR_SUCCESS : UiTokens.COLOR_CARD_BORDER })
          }
          .width(30)
          .height(30)
          .borderRadius(10)

          Column({ space: 2 }) {
            Text('开放 API 统计')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text(this.vm.openApiStats !== null ? 'Music Tag Web 已连接' : '正在同步 Music Tag Web')
              .fontSize(10)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.vm.openApiStatsLoading) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color(UiTokens.COLOR_PRIMARY)
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
                void this.vm.loadOpenApiStats();
              })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.vm.openApiStats !== null) {
          Row({ space: 6 }) {
            this.apiMetricTile('专辑', this.vm.openApiStats.albumCount)
            this.apiMetricTile('歌曲', this.vm.openApiStats.trackCount)
            this.apiMetricTile('歌手', this.vm.openApiStats.artistCount)
          }
          .width('100%')

          Row({ space: 6 }) {
            this.apiInfoChip('容量', this.vm.openApiStats.songSize)
            this.apiInfoChip('时长', this.vm.openApiStats.songDuration)
          }
          .width('100%')

          if ((this.vm.openApiStats.nowPlaying ?? '').length > 0) {
            Row({ space: 7 }) {
              Column()
                .width(4)
                .height(24)
                .borderRadius(2)
                .backgroundColor(UiTokens.COLOR_SUCCESS)
              Column({ space: 2 }) {
                Text('服务端正在播放')
                  .fontSize(9)
                  .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
                Text(this.vm.openApiStats.nowPlaying ?? '-')
                  .fontSize(11)
                  .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .height(34)
            .padding({ left: 8, right: 8 })
            .alignItems(VerticalAlign.Center)
            .borderRadius(10)
            .backgroundColor(UiTokens.COLOR_SUCCESS_SOFT_BG)
          }
        } else if (this.vm.openApiStatsError.length > 0) {
          Row({ space: 8 }) {
            Column()
              .width(6)
              .height(6)
              .borderRadius(3)
              .backgroundColor(UiTokens.COLOR_WARNING)
            Text(this.vm.openApiStatsError)
              .layoutWeight(1)
              .fontSize(11)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ left: 10, right: 10, top: 9, bottom: 9 })
          .borderRadius(12)
          .backgroundColor(UiTokens.COLOR_WARNING_SOFT_BG)
        } else {
          Text('等待开放 API 数据返回')
            .width('100%')
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .padding({ left: 10, right: 10, top: 9, bottom: 9 })
            .borderRadius(12)
            .backgroundColor('#107B6BA8')
        }
      }
      .width('100%')
      .padding(11)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .borderRadius(14)
    .backgroundColor(UiTokens.COLOR_CARD_BG)
    .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
    .border({ width: 1, color: UiTokens.COLOR_CARD_BORDER })
    .clip(true)
  }

  private async appendAlbumToPlaylist(album: Album): Promise<void> {
    try {
      const added: number = await PlaybackService.appendAlbumToPlaylist(album.id);
      this.showToast(added > 0 ? `已添加 ${added} 首到播放列表` : '曲目已在播放列表中');
    } catch (err) {
      this.showToast((err as Error).message || '添加失败');
    }
  }

  private coverUrl(coverArt: string | undefined, size: number): string | undefined {
    if (coverArt === undefined || coverArt.length === 0) {
      return undefined;
    }
    return CoverDisplayResolver.resolve(coverArt, size);
  }

  @Builder
  private albumCover(album: Album, radius: number) {
    if (album.coverArt !== undefined && album.coverArt.length > 0) {
      Image(this.coverUrl(album.coverArt, 360))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(radius)
        .onVisibleAreaChange([0.0, 1.0], (visible: boolean, ratio: number) => {
          if (visible && ratio >= 0.8 && album.coverArt !== undefined) {
            CoverDisplayResolver.enqueueWhenVisible(album.coverArt);
          }
        })
    } else {
      Column() {
        Text('♪')
          .fontSize(30)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(radius)
      .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
    }
  }

  @Builder
  private homeHero() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column()
        .width('100%')
        .height(206)
        .borderRadius(24)
        .linearGradient({
          angle: 140,
          colors: [['#FF151B3D', 0], ['#FF3A236A', 0.54], ['#FF174D69', 1]]
        })
      Column()
        .width(150)
        .height(150)
        .borderRadius(75)
        .backgroundColor('#267C5CFF')
        .blur(30)
        .translate({ x: 218, y: -82 })
      Column()
        .width(120)
        .height(120)
        .borderRadius(60)
        .backgroundColor('#2072E9FF')
        .blur(26)
        .translate({ x: -42, y: 74 })

      Column({ space: 14 }) {
        Row() {
          Row({ space: 6 }) {
            Column()
              .width(7)
              .height(7)
              .borderRadius(4)
              .backgroundColor('#FF70FFD1')
            Text('SONIC LINK')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(1.4)
              .fontColor('#CCFFFFFF')
          }
          Blank()
          Text(this.loggedInEndpoint === 'local' ? 'LAN · LOW LATENCY' : 'REMOTE · ONLINE')
            .fontSize(9)
            .letterSpacing(0.7)
            .fontColor('#B3FFFFFF')
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .borderRadius(10)
            .backgroundColor('#18FFFFFF')
        }
        .width('100%')

        Column({ space: 5 }) {
          Text('你的音乐宇宙')
            .fontSize(29)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('由 Subsonic 实时驱动的私人声场')
            .fontSize(13)
            .fontColor('#C7FFFFFF')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row({ space: 10 }) {
          Button() {
            Row({ space: 7 }) {
              if (this.playActionLoading) {
                LoadingProgress()
                  .width(17)
                  .height(17)
                  .color('#FF1B2140')
              } else {
                Image($r('app.media.cb_play'))
                  .width(17)
                  .height(17)
                  .fillColor('#FF1B2140')
              }
              Text('随机声波')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FF1B2140')
            }
          }
          .height(40)
          .padding({ left: 16, right: 16 })
          .borderRadius(20)
          .backgroundColor('#FFF1F4FF')
          .onClick(() => {
            void this.startSonicDiscovery();
          })
          Text('60 TRACKS · SHUFFLED')
            .fontSize(9)
            .letterSpacing(0.6)
            .fontColor('#99FFFFFF')
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding(18)
    }
    .width('100%')
    .height(206)
    .clip(true)
  }

  @Builder
  private nowPlayingPanel() {
    if (this.playback.showMiniPlayer && this.playback.track !== null) {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.playback.track.coverArtId.length > 0) {
            Image(this.coverUrl(this.playback.track.coverArtId, 160))
              .width(54)
              .height(54)
              .objectFit(ImageFit.Cover)
              .borderRadius(16)
          } else {
            Column() {
              Image($r('app.media.dock_music_note'))
                .width(24)
                .height(24)
                .fillColor(UiTokens.COLOR_PRIMARY)
            }
            .width(54)
            .height(54)
            .justifyContent(FlexAlign.Center)
            .borderRadius(16)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
          }
        }
        .width(54)
        .height(54)
        Column({ space: 4 }) {
          Text('NOW TRANSMITTING')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .fontColor(UiTokens.COLOR_PRIMARY)
          AutoMarqueeText({
            text: this.playback.track.title,
            fontSize: 15,
            fontWeight: FontWeight.Medium,
            fontColor: UiTokens.COLOR_TEXT_PRIMARY
          })
            .width('100%')
            .height(20)
          Text(this.playback.track.artist)
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Image(this.playback.isPlaying() ? $r('app.media.cb_pause') : $r('app.media.cb_play'))
          .width(22)
          .height(22)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
          .padding(10)
          .onClick(() => {
            void PlaybackService.toggle();
          })
      }
      .width('100%')
      .padding(12)
      .borderRadius(18)
      .backgroundColor(UiTokens.COLOR_CARD_BG)
      .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
      .border({ width: 1, color: UiTokens.COLOR_CARD_BORDER })
      .onClick(() => {
        this.appPathStack.pushPathByName('NowPlayingPage', null);
      })
    }
  }

  @Builder
  private featuredRail() {
    if (this.vm.featuredAlbums.length > 0 && !this.vm.isSearchMode) {
      Column({ space: 10 }) {
        Row() {
          Column({ space: 2 }) {
            Text('灵感漫游')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text('从你的曲库随机捕获')
              .fontSize(11)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('刷新')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_PRIMARY)
            .onClick(() => {
              void this.vm.loadHome();
            })
        }
        .width('100%')

        Scroll() {
          Row({ space: 12 }) {
            ForEach(this.vm.featuredAlbums, (album: Album) => {
              Column({ space: 7 }) {
                Stack({ alignContent: Alignment.BottomEnd }) {
                  this.albumCover(album, 16)
                  Button({ type: ButtonType.Circle }) {
                    Image($r('app.media.cb_play'))
                      .width(16)
                      .height(16)
                      .fillColor(Color.White)
                  }
                  .width(34)
                  .height(34)
                  .margin(7)
                  .backgroundColor('#B3151B3D')
                  .onClick(() => {
                    void this.playAlbum(album);
                  })
                }
                .width(126)
                .height(126)
                Text(album.title ?? album.name ?? '未知专辑')
                  .width(126)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                this.openAlbum(album);
              })
            }, (album: Album) => `featured-${album.id}`)
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
    }
  }

  @Builder
  private feedChip(title: string, tab: LibraryTab) {
    Text(title)
      .fontSize(12)
      .fontWeight(this.vm.tab === tab && !this.vm.isSearchMode ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.vm.tab === tab && !this.vm.isSearchMode ?
        UiTokens.COLOR_TEXT_ON_BRAND : UiTokens.COLOR_TEXT_SECONDARY)
      .padding({ left: 13, right: 13, top: 8, bottom: 8 })
      .borderRadius(16)
      .backgroundColor(this.vm.tab === tab && !this.vm.isSearchMode ?
        UiTokens.COLOR_PRIMARY : UiTokens.COLOR_CARD_BG)
      .onClick(() => {
        this.selectFeed(tab);
      })
  }

  @Builder
  private homeHeader() {
    Column({ space: 16 }) {
      this.homeHero()
      this.nowPlayingPanel()
      this.featuredRail()

      GlassSearchBar({
        keyword: this.searchKeyword,
        onKeywordChange: (value: string) => {
          this.searchKeyword = value;
        },
        placeholder: '搜索专辑、歌手与声场',
        sidePadding: 0,
        onSubmit: () => {
          this.submitSearch();
        }
      })

      Row({ space: 8 }) {
        this.feedChip('最近入库', 'newest')
        this.feedChip('常听专辑', 'frequent')
        this.feedChip('随机漫游', 'random')
      }
      .width('100%')

      Row() {
        Column({ space: 2 }) {
          Text(this.feedTitle())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text(this.feedSubtitle())
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      top: ImmersivePageOffsets.contentTopPadding(HeartTonePageRole.TAB_ROOT, this.topInset)
    })
    .margin({ bottom: UiTokens.SECTION_GAP })
  }

  @Builder
  private albumCard(album: Album) {
    CardContainer() {
      Column({ space: 10 }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          this.albumCover(album, 12)
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_more_vert'))
              .width(19)
              .height(19)
              .fillColor(Color.White)
          }
          .width(32)
          .height(32)
          .margin(6)
          .backgroundColor('#78000000')
          .bindMenu([
            { value: '播放全部', action: (): void => { void this.playAlbum(album); } },
            { value: '添加到播放列表', action: (): void => { void this.appendAlbumToPlaylist(album); } }
          ])
        }
        .width('100%')
        .aspectRatio(1)
        .clip(true)
        Column({ space: 4 }) {
          AutoMarqueeText({
            text: album.title ?? album.name ?? '未知专辑',
            fontSize: 15,
            fontWeight: FontWeight.Medium,
            fontColor: UiTokens.COLOR_TEXT_PRIMARY
          })
            .width('100%')
            .height(UiTokens.LIBRARY_CARD_TITLE_HEIGHT)
          Text(album.artist.length > 0 ? album.artist : '未知歌手')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_MUSIC_ARTIST)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private albumsList() {
    List({ scroller: this.tabScrollerBridge.scrollerForTab(1) }) {
      ListItemGroup({ header: this.homeHeader }) {
        if (this.vm.isLoading && this.vm.albums.length === 0) {
          ListItem() { LoadingState({ message: '正在同步你的音乐宇宙…' }) }
        } else if (this.vm.errorMessage.length > 0 && this.vm.albums.length === 0) {
          ListItem() {
            Column() {
              ErrorState({ message: this.vm.errorMessage, onRetryPress: () => { this.retryLoad(); } })
              if (this.vm.authExpired) {
                SuccessButton({
                  text: '重新登录',
                  onPressed: () => { this.appPathStack.replacePathByName('LoginPage', null); }
                }).margin({ top: 10 })
              }
            }
          }
        } else if (this.vm.albums.length === 0) {
          ListItem() {
            EmptyState({
              title: this.vm.isSearchMode ? '没有捕获到信号' : '音乐宇宙还是空的',
              subtitle: this.vm.isSearchMode ? '换一个关键词再试试' : '请先向服务器添加音乐'
            })
          }
        } else {
          ForEach(this.vm.albums, (album: Album) => {
            ListItem() {
              this.albumCard(album)
            }
            .margin({ bottom: LibraryGridLayout.mainAxisItemGap() })
            .onClick(() => {
              this.openAlbum(album);
            })
          }, (album: Album) => `${this.vm.tab}-${album.id}`)
        }

        if (this.vm.isLoadingMore) {
          ListItem() {
            Row({ space: 8 }) {
              LoadingProgress().width(20).height(20).color(UiTokens.COLOR_PRIMARY)
              Text('正在接收更多音乐信号…')
                .fontSize(12)
                .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding(12)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: UiTokens.LIBRARY_PAGE_HORIZONTAL_PADDING, right: UiTokens.LIBRARY_PAGE_HORIZONTAL_PADDING })
    .contentEndOffset(ImmersivePageOffsets.tabContentEnd(this.bottomInset, this.rootTabActive))
    .lanes(this.vm.albums.length > 0 ? this.gridColumns : 1, LibraryGridLayout.lanesGap())
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onAreaChange((_oldValue, newValue) => {
      const widthVp: number = LibraryGridLayout.contentWidthFromListArea(this.getUIContext(), newValue.width);
      this.updateGridColumnsByWidth(widthVp);
    })
    .onReachEnd(() => {
      void this.vm.loadMore();
    })
  }

  aboutToAppear(): void {
    void this.syncOpenApiTokenState();
    this.onAuthSnapshotChanged();
  }

  private async syncOpenApiTokenState(): Promise<void> {
    const token: string = await OpenApiCredentialStore.getToken();
    this.hasOpenApiToken = token.length > 0;
    if (!this.hasOpenApiToken) {
      this.vm.openApiStats = null;
      this.vm.openApiStatsError = '';
    }
  }

  private onAuthSnapshotChanged(): void {
    if (this.authPhase === 'authenticated') {
      this.searchKeyword = this.vm.searchQuery;
      if (this.vm.albums.length === 0) {
        void this.vm.loadHome();
      }
    } else if (this.authPhase === 'anonymous') {
      this.vm.reset();
    }
  }

  @LocalBuilder
  buildBootingBody() {
    Column() { LoadingState({ message: '正在建立 SONIC LINK…' }) }
      .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @LocalBuilder
  buildAnonymousBody() {
    Column() { }
      .width('100%').height('100%')
  }

  @Builder
  private scaffold(content: () => void) {
    HeartTonePageLayout({
      options: {
        role: HeartTonePageRole.TAB_ROOT,
        barToneTabIndex: 1,
        scrollMode: HeartToneScrollMode.SCROLL
      },
      content: content
    })
  }

  build() {
    if (this.authPhase === 'authenticated' && this.isLoggedIn) {
      Stack() {
        GlobalPageBackground()
        Column() { this.albumsList() }
          .width('100%')
          .height('100%')
      }
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .id('bar-tone-probe-1')
    } else if (this.authPhase === 'booting') {
      this.scaffold(this.buildBootingBody)
    } else {
      this.scaffold(this.buildAnonymousBody)
    }
  }
}
