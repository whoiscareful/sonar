import { AuthSession } from '../auth/AuthSession';
import { CoverCacheStore } from '../cache/CoverCacheStore';
import { SongCacheStore } from '../cache/SongCacheStore';
import { DangerButton } from '../components/buttons/DangerButton';
import { CardContainer } from '../components/layout/CardContainer';
import { HeartTonePageLayout } from '../components/layout/HeartTonePageLayout';
import { Logger } from '../common/Logger';
import { ScreenProfileStore } from '../ui/adaptation/ScreenProfileStore';
import {
  HeartTonePageLayoutOptions,
  HeartTonePageRole,
  HeartToneScrollMode
} from '../ui/layout/HeartTonePageLayoutOptions';
import { GlassSurfaceHelper } from '../ui/material/GlassSurfaceHelper';
import { UiTokens } from '../ui/tokens/UiTokens';
import { ProfileAppearanceStore } from '../settings/ProfileAppearanceStore';

const LOGOUT_DESTINATION_TAB_INDEX: number = 2;
const QUICK_ACTION_HEIGHT: number = 112;

@Component
export struct ProfilePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInUser') loggedInUser: string = '';
  @StorageLink('loggedInServer') loggedInServer: string = '';
  @StorageLink('loggedInEndpoint') loggedInEndpoint: string = 'remote';
  @StorageLink('songCacheUsedBytes') songCacheUsedBytes: number = 0;
  @StorageLink('coverCacheUsedBytes') coverCacheUsedBytes: number = 0;
  @StorageLink('outerScreenPreview') outerScreenPreview: boolean = false;
  @StorageLink('profileAppearanceRevision') @Watch('onAppearanceChanged') profileAppearanceRevision: number = 0;
  @State private avatarUri: string = '';
  private readonly appearanceStore: ProfileAppearanceStore = ProfileAppearanceStore.getInstance();

  aboutToAppear(): void {
    this.onAppearanceChanged();
  }

  private onAppearanceChanged(): void {
    this.avatarUri = this.appearanceStore.avatarUri();
  }

  private layoutOptions(): HeartTonePageLayoutOptions {
    return {
      role: HeartTonePageRole.TAB_ROOT,
      barToneTabIndex: 2,
      scrollMode: HeartToneScrollMode.SCROLL
    };
  }

  private displayName(): string {
    if (!this.isLoggedIn) {
      return '欢迎使用 HeartTone';
    }
    return this.loggedInUser.length > 0 ? this.loggedInUser : '已登录用户';
  }

  private avatarText(): string {
    if (!this.isLoggedIn || this.loggedInUser.length === 0) {
      return 'H';
    }
    return this.loggedInUser.slice(0, 1).toUpperCase();
  }

  private endpointLabel(): string {
    if (!this.isLoggedIn) {
      return '未连接';
    }
    return this.loggedInEndpoint === 'local' ? '本地加速' : '远程连接';
  }

  private serverSummary(): string {
    if (!this.isLoggedIn) {
      return '连接你的 Subsonic / Navidrome 服务器';
    }
    return this.loggedInServer.length > 0 ? this.loggedInServer : '服务器已连接';
  }

  private cacheTotalText(): string {
    return SongCacheStore.formatBytes(this.songCacheUsedBytes + this.coverCacheUsedBytes);
  }

  private toggleOuterScreenPreview(): void {
    ScreenProfileStore.setPreviewEnabled(!this.outerScreenPreview);
  }

  private async handleLogout(): Promise<void> {
    await AuthSession.signOut();
    AppStorage.setOrCreate<number>('rootTabIndex', LOGOUT_DESTINATION_TAB_INDEX);
  }

  @Builder
  private sectionTitle(title: string, subtitle: string) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(subtitle)
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 2, right: 2 })
  }

  @Builder
  private quickAction(
    icon: Resource,
    title: string,
    subtitle: string,
    iconColor: ResourceColor,
    iconBackground: ResourceColor,
    action: () => void
  ) {
    Column({ space: 10 }) {
      Row() {
        Column() {
          Image(icon)
            .width(22)
            .height(22)
            .fillColor(iconColor)
        }
        .width(42)
        .height(42)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(14)
        .backgroundColor(iconBackground)
        Blank()
        Text('›')
          .fontSize(20)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          .maxLines(1)
        Text(subtitle)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .height(QUICK_ACTION_HEIGHT)
    .padding(12)
    .borderRadius(UiTokens.RADIUS_CARD)
    .backgroundColor(UiTokens.COLOR_CARD_BG)
    .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
    .border({ width: 1, color: UiTokens.COLOR_CARD_BORDER })
    .onClick(() => {
      action();
    })
  }

  @Builder
  private settingsRow(icon: Resource, title: string, subtitle: string, action: () => void) {
    Row({ space: 12 }) {
      Column() {
        Image(icon)
          .width(21)
          .height(21)
          .fillColor(UiTokens.COLOR_PRIMARY)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(12)
      .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(subtitle)
          .fontSize(11)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(20)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
    }
    .width('100%')
    .height(64)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      action();
    })
  }

  @Builder
  private profileHero() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 16 }) {
      Row({ space: 13 }) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.avatarUri.length > 0) {
            Image(this.avatarUri)
              .width(58)
              .height(58)
              .borderRadius(20)
              .objectFit(ImageFit.Cover)
          } else {
            Column()
              .width(58)
              .height(58)
              .borderRadius(20)
              .linearGradient({
                angle: 145,
                colors: [[UiTokens.COLOR_PRIMARY, 0], [UiTokens.COLOR_INFO, 1]]
              })
            Text(this.avatarText())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
          }
        }
        .width(58)
        .height(58)
        Column({ space: 5 }) {
          Text(this.displayName())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            .maxLines(1)
          Row({ space: 6 }) {
            Column()
              .width(7)
              .height(7)
              .borderRadius(4)
              .backgroundColor(this.isLoggedIn ? UiTokens.COLOR_SUCCESS : UiTokens.COLOR_TEXT_TERTIARY)
            Text(this.endpointLabel())
              .fontSize(12)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('个性化')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_PRIMARY)
          .padding({ left: 13, right: 13, top: 8, bottom: 8 })
          .borderRadius(16)
          .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
          .onClick(() => {
            this.appPathStack.pushPathByName('PersonalizationPage', null);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.serverSummary())
        .fontSize(12)
        .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
        Column({ space: 3 }) {
          Text(this.cacheTotalText())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text('本地缓存')
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Column({ space: 3 }) {
          Text(this.outerScreenPreview ? '外屏预览' : '常规界面')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text('显示模式')
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 13 })
      .border({ width: { top: 1 }, color: UiTokens.COLOR_CARD_BORDER })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .borderRadius(20)
    .clip(true)
    .backgroundColor(UiTokens.COLOR_CARD_BG)
    .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
    .border({ width: 1, color: UiTokens.COLOR_CARD_BORDER })
  }

  @LocalBuilder
  buildProfileBody() {
    Column({ space: UiTokens.SECTION_GAP }) {
      this.profileHero()

      this.sectionTitle('常用功能', '常用操作一步直达')

      Row({ space: UiTokens.SECTION_GAP }) {
        this.quickAction(
          $r('app.media.lib_icon_7'),
          '服务器',
          this.endpointLabel(),
          UiTokens.COLOR_INFO,
          UiTokens.COLOR_INFO_SOFT_BG,
          () => {
            this.appPathStack.pushPathByName('ServerPage', null);
          }
        )
        this.quickAction(
          $r('app.media.tab_library'),
          '缓存管理',
          this.cacheTotalText(),
          UiTokens.COLOR_SUCCESS,
          UiTokens.COLOR_SUCCESS_SOFT_BG,
          () => {
            this.appPathStack.pushPathByName('CacheSettingsPage', null);
          }
        )
      }
      .width('100%')

      this.sectionTitle('更多设置', '账户、数据与高级功能')

      CardContainer() {
        Column() {
          this.settingsRow(
            $r('app.media.ic_playlist_library'),
            '我的歌单',
            '喜爱、本地歌单与平台链接导入',
            () => {
              this.appPathStack.pushPathByName('PlaylistLibraryPage', null);
            }
          )
          Divider()
            .color(UiTokens.COLOR_CARD_BORDER)
            .margin({ left: 52 })
          this.settingsRow(
            $r('app.media.ic_statistics'),
            '音乐统计',
            '听歌趋势、时长与曲库概览',
            () => {
              this.appPathStack.pushPathByName('MusicStatsPage', null);
            }
          )
          Divider()
            .color(UiTokens.COLOR_CARD_BORDER)
            .margin({ left: 52 })
          this.settingsRow(
            $r('app.media.ic_data_management'),
            '数据管理',
            '删除缓存、听歌记录与个人数据',
            () => {
              this.appPathStack.pushPathByName('DataManagementPage', null);
            }
          )
          Divider()
            .color(UiTokens.COLOR_CARD_BORDER)
            .margin({ left: 52 })
          this.settingsRow(
            $r('app.media.tab_profile'),
            '个性化配置',
            '头像、个人封面与显示偏好',
            () => {
              this.appPathStack.pushPathByName('PersonalizationPage', null);
            }
          )
          Divider()
            .color(UiTokens.COLOR_CARD_BORDER)
            .margin({ left: 52 })
          this.settingsRow(
            $r('app.media.tab_album'),
            '外屏预览',
            this.outerScreenPreview ? '点击退出外屏预览' : '预览方形播放器界面',
            () => {
              this.toggleOuterScreenPreview();
            }
          )
          Divider()
            .color(UiTokens.COLOR_CARD_BORDER)
            .margin({ left: 52 })
          this.settingsRow(
            $r('app.media.lib_icon_103'),
            '备份与恢复',
            '导出或恢复登录配置与个人数据',
            () => {
              this.appPathStack.pushPathByName('ExportConfigPage', null);
            }
          )
          Divider()
            .color(UiTokens.COLOR_CARD_BORDER)
            .margin({ left: 52 })
          this.settingsRow(
            $r('app.media.lib_icon_7'),
            '服务器设置',
            this.serverSummary(),
            () => {
              this.appPathStack.pushPathByName('ServerPage', null);
            }
          )
        }
      }

      if (this.isLoggedIn) {
        CardContainer() {
          Column({ space: 10 }) {
            Text('账户操作')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              .width('100%')
            DangerButton({
              text: '退出登录',
              onPressed: () => {
                this.handleLogout().catch((err: Error) => {
                  Logger.error('ProfilePage', `logout failed: ${err.message}`);
                });
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
    }
    .width('100%')
  }

  build() {
    HeartTonePageLayout({
      options: this.layoutOptions(),
      content: this.buildProfileBody
    })
  }
}
