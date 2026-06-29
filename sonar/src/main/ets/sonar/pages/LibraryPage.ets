import { LibraryViewModel } from '../viewmodel/LibraryViewModel';
import { Album, AlbumDetailRouteParam } from '../api/SubsonicTypes';
import { CoverDisplayResolver } from '../cache/CoverDisplayResolver';
import { SuccessButton } from '../components/buttons/SuccessButton';
import { LoadingState } from '../components/feedback/LoadingState';
import { EmptyState } from '../components/feedback/EmptyState';
import { ErrorState } from '../components/feedback/ErrorState';
import { CardContainer } from '../components/layout/CardContainer';
import { AutoMarqueeText } from '../components/layout/AutoMarqueeText';
import { GlassSearchBar } from '../components/forms/GlassSearchBar';
import { SonarPageLayout } from '../components/layout/SonarPageLayout';
import { ImmersivePageOffsets } from '../ui/layout/ImmersivePageOffsets';
import { LibraryGridLayout } from '../ui/layout/LibraryGridLayout';
import { TabScrollerBridge } from '../ui/layout/TabScrollerBridge';
import {
  SonarPageRole,
  SonarScrollMode
} from '../ui/layout/SonarPageLayoutOptions';
import { UiTokens } from '../ui/tokens/UiTokens';
import { ToastUtil } from '../common/ToastUtil';
import { PlaybackService } from '../playback/PlaybackService';

@Component
export struct LibraryPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Consume('tabScrollerBridge') tabScrollerBridge: TabScrollerBridge = new TabScrollerBridge();
  @StorageLink('authPhase') @Watch('onAuthSnapshotChanged') authPhase: string = 'booting';
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('rootTabActive') rootTabActive: boolean = false;
  /** 封面落盘后 bump，触发页面重建以切换本地 file URI */
  @StorageLink('coverCacheRevision') coverCacheRevision: number = 0;
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @State vm: LibraryViewModel = new LibraryViewModel();
  @State private _searchKeyword: string = '';
  @State private _gridColumns: number = UiTokens.LIBRARY_GRID_MIN_COLUMNS;
  @State private _playAllLoading: boolean = false;

  private updateGridColumnsByWidth(widthVp: number): void {
    const nextColumns: number = LibraryGridLayout.resolveColumns(widthVp);
    if (nextColumns !== this._gridColumns) {
      this._gridColumns = nextColumns;
    }
  }

  private submitSearch(): void {
    const keyword: string = this._searchKeyword.trim();
    if (keyword.length === 0) {
      if (this.vm.isSearchMode || this.vm.searchQuery.length > 0) {
        void this.vm.loadNewest();
      }
      return;
    }
    if (this.vm.isSearchMode && keyword === this.vm.searchQuery) {
      return;
    }
    void this.vm.searchAlbums(keyword);
  }

  private retryLoad(): void {
    if (this.vm.isSearchMode) {
      void this.vm.searchAlbums(this.vm.searchQuery);
      return;
    }
    void this.vm.loadNewest();
  }

  private showToast(message: string): void {
    ToastUtil.show(this, message, 1600);
  }

  private async playAllAlbum(album: Album): Promise<void> {
    if (this._playAllLoading) {
      return;
    }
    this._playAllLoading = true;
    try {
      await PlaybackService.playAlbumAll(album);
      PlaybackService.setPlaybackMode('listLoop');
    } catch (err) {
      const message: string = (err as Error).message;
      if (message === 'EMPTY_ALBUM') {
        this.showToast('暂无曲目');
      } else {
        this.showToast(message.length > 0 ? message : '加载专辑失败');
      }
    } finally {
      this._playAllLoading = false;
    }
  }

  private async appendAlbumToPlaylist(album: Album): Promise<void> {
    try {
      const added: number = await PlaybackService.appendAlbumToPlaylist(album.id);
      const title: string = album.title ?? album.name ?? '专辑';
      if (added > 0) {
        this.showToast(`已添加 ${added} 首到播放列表：${title}`);
      } else {
        this.showToast(`曲目已在播放列表中：${title}`);
      }
    } catch (err) {
      const message: string = (err as Error).message;
      this.showToast(message.length > 0 ? message : '添加失败');
    }
  }

  @Builder
  private buildAlbumCover(album: Album) {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (album.coverArt !== undefined && album.coverArt.length > 0) {
        Image(this.vm.coverUrl(album.coverArt))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .alt('#E5E5EA')
          .onVisibleAreaChange([0.0, 1.0], (visible: boolean, ratio: number) => {
            if (visible && ratio >= 1.0) {
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
        .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Image($r('app.media.ic_more_vert'))
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
      }
      .width(32)
      .height(32)
      .backgroundColor('#66000000')
      .margin(6)
      .hitTestBehavior(HitTestMode.Block)
      .accessibilityText('更多操作')
      .responseRegion({ width: 40, height: 40 })
      .bindMenu([
        {
          value: '播放全部',
          action: (): void => {
            void this.playAllAlbum(album);
          }
        },
        {
          value: '添加到播放列表',
          action: (): void => {
            void this.appendAlbumToPlaylist(album);
          }
        }
      ])
    }
    .width('100%')
    .aspectRatio(1)
    .borderRadius(10)
    .clip(true)
  }

  @Builder
  private buildAlbumCard(album: Album) {
    CardContainer() {
      Column({ space: 10 }) {
        this.buildAlbumCover(album)

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
            .fontSize(13)
            .fontColor(UiTokens.COLOR_MUSIC_ARTIST)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
  }

  @Builder
  private buildLibrarySearchHeader() {
    Column() {
      GlassSearchBar({
        keyword: this._searchKeyword,
        onKeywordChange: (value: string) => {
          this._searchKeyword = value;
        },
        placeholder: '搜索专辑',
        sidePadding: 0,
        onSubmit: () => {
          this.submitSearch();
        }
      })
    }
    .width('100%')
    .padding({
      top: ImmersivePageOffsets.contentTopPadding(SonarPageRole.TAB_ROOT, this.topInset)
    })
    .margin({ bottom: UiTokens.SECTION_GAP })
  }

  @Builder
  private buildAlbumsList() {
    List({ scroller: this.tabScrollerBridge.scrollerForTab(1) }) {
      ListItemGroup({ header: this.buildLibrarySearchHeader }) {
      if (this.vm.isLoading && this.vm.albums.length === 0) {
        ListItem() {
          LoadingState({ message: this.vm.isSearchMode ? '正在搜索专辑…' : '正在获取专辑…' })
        }
      } else if (this.vm.errorMessage.length > 0 && this.vm.albums.length === 0) {
        ListItem() {
          Column() {
            ErrorState({
              message: this.vm.errorMessage,
              onRetryPress: () => {
                this.retryLoad();
              }
            })
            if (this.vm.authExpired) {
              SuccessButton({
                text: '重新登录',
                onPressed: () => {
                  this.appPathStack.replacePathByName('LoginPage', null);
                }
              })
              .margin({ top: 10 })
            }
          }
          .width('100%')
          .padding({ left: 6, right: 6 })
        }
      } else if (this.vm.albums.length === 0) {
        ListItem() {
          EmptyState({
            title: this.vm.isSearchMode ? '未找到结果' : '暂无数据',
            subtitle: this.vm.isSearchMode ? '试试更换关键词后再回车搜索' : '还没有专辑'
          })
        }
      } else {
        ForEach(this.vm.albums, (album: Album) => {
          ListItem() {
            this.buildAlbumCard(album)
          }
          .margin({ bottom: LibraryGridLayout.mainAxisItemGap() })
          .onClick(() => {
            const routeParam: AlbumDetailRouteParam = { albumId: album.id };
            this.appPathStack.pushPathByName('AlbumDetailPage', routeParam);
          })
        }, (album: Album) => album.id)
      }

      if (this.vm.isLoadingMore) {
        ListItem() {
          Row() {
            LoadingProgress()
              .width(22)
              .height(22)
              .color(UiTokens.COLOR_TEXT_SECONDARY)
            Text('加载中…')
              .fontSize(13)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              .margin({ left: 8 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 8, bottom: 8 })
        }
      }
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: UiTokens.LIBRARY_PAGE_HORIZONTAL_PADDING,
      right: UiTokens.LIBRARY_PAGE_HORIZONTAL_PADDING
    })
    .backgroundColor(Color.Transparent)
    .contentEndOffset(ImmersivePageOffsets.tabContentEnd(this.bottomInset, this.rootTabActive))
    .lanes(this.vm.albums.length > 0 ? this._gridColumns : 1, LibraryGridLayout.lanesGap())
    .listDirection(Axis.Vertical)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onAreaChange((_oldValue, newValue) => {
      const widthVp: number = LibraryGridLayout.contentWidthFromListArea(
        this.getUIContext(), newValue.width);
      this.updateGridColumnsByWidth(widthVp);
    })
    .onReachEnd(() => {
      void this.vm.loadMore();
    })
  }

  aboutToAppear(): void {
    this.onAuthSnapshotChanged();
  }

  private onAuthSnapshotChanged(): void {
    if (this.authPhase === 'authenticated') {
      this.activateLibrary();
    } else if (this.authPhase === 'anonymous') {
      this.vm.reset();
    }
  }

  private activateLibrary(): void {
    this._searchKeyword = this.vm.searchQuery;
    if (this.vm.albums.length === 0) {
      if (this._searchKeyword.length > 0) {
        void this.vm.searchAlbums(this._searchKeyword);
      } else {
        void this.vm.loadNewest();
      }
    }
  }

  @LocalBuilder
  buildBootingBody() {
    Column() {
      LoadingState({ message: '正在恢复会话…' })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @LocalBuilder
  buildAnonymousBody() {
    Column() {
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildBootingScaffold() {
    SonarPageLayout({
      options: {
        role: SonarPageRole.TAB_ROOT,
        barToneTabIndex: 1,
        scrollMode: SonarScrollMode.SCROLL
      },
      content: this.buildBootingBody
    })
  }

  @Builder
  private buildAnonymousScaffold() {
    SonarPageLayout({
      options: {
        role: SonarPageRole.TAB_ROOT,
        barToneTabIndex: 1,
        scrollMode: SonarScrollMode.SCROLL
      },
      content: this.buildAnonymousBody
    })
  }

  @Builder
  private buildAuthenticatedScaffold() {
    Column() {
      this.buildAlbumsList()
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .id('bar-tone-probe-1')
  }

  build() {
    if (this.authPhase === 'authenticated' && this.isLoggedIn) {
      this.buildAuthenticatedScaffold()
    } else if (this.authPhase === 'booting') {
      this.buildBootingScaffold()
    } else {
      this.buildAnonymousScaffold()
    }
  }
}
