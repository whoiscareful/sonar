import { AuthSession } from '../auth/AuthSession';
import { CoverCacheStore } from '../cache/CoverCacheStore';
import { SongCacheStore } from '../cache/SongCacheStore';
import { DangerButton } from '../components/buttons/DangerButton';
import { OuterScreenPreviewEntry } from '../components/debug/OuterScreenPreviewEntry';
import { CardContainer } from '../components/layout/CardContainer';
import { SonarPageLayout } from '../components/layout/SonarPageLayout';
import {
  SonarPageLayoutOptions,
  SonarPageRole,
  SonarScrollMode
} from '../ui/layout/SonarPageLayoutOptions';
import { UiTokens } from '../ui/tokens/UiTokens';

const LOGOUT_DESTINATION_TAB_INDEX: number = 2;

@Component
export struct ProfilePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInUser') loggedInUser: string = '';
  @StorageLink('loggedInServer') loggedInServer: string = '';
  @StorageLink('songCacheUsedBytes') songCacheUsedBytes: number = 0;
  @StorageLink('coverCacheUsedBytes') coverCacheUsedBytes: number = 0;

  private layoutOptions(): SonarPageLayoutOptions {
    return {
      role: SonarPageRole.TAB_ROOT,
      barToneTabIndex: 2,
      scrollMode: SonarScrollMode.SCROLL
    };
  }

  private async handleLogout(): Promise<void> {
    await AuthSession.signOut();
    AppStorage.setOrCreate<number>('rootTabIndex', LOGOUT_DESTINATION_TAB_INDEX);
  }

  @LocalBuilder
  buildProfileBody() {
    Column({ space: UiTokens.SECTION_GAP }) {
      OuterScreenPreviewEntry()

      CardContainer() {
        Row() {
          Column({ space: 4 }) {
            Text('服务器')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text(this.isLoggedIn ? this.loggedInServer : '连接与登录设置')
              .fontSize(12)
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
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.appPathStack.pushPathByName('ServerPage', null);
        })
      }

      CardContainer() {
      Row() {
        Column({ space: 4 }) {
          Text('缓存设置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text(`音乐 ${SongCacheStore.formatBytes(this.songCacheUsedBytes)} · 封面 ${CoverCacheStore.formatBytes(this.coverCacheUsedBytes)}`)
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('›')
          .fontSize(20)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.appPathStack.pushPathByName('CacheSettingsPage', null);
      })
    }

    CardContainer() {
      Row() {
        Column({ space: 4 }) {
          Text('导出配置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text('导出服务器登录信息')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('›')
          .fontSize(20)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.appPathStack.pushPathByName('ExportConfigPage', null);
      })
    }

    CardContainer() {
      Column({ space: 10 }) {
        Text(this.isLoggedIn ? (this.loggedInUser.length > 0 ? this.loggedInUser : '已登录用户') : '未登录')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(this.isLoggedIn ? this.loggedInServer : '请在我的 > 服务器完成登录')
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        if (this.isLoggedIn) {
          DangerButton({
            text: '退出登录',
            onPressed: () => {
              this.handleLogout().catch((err: Error) => {
                console.error(`logout failed: ${err.message}`);
              });
            }
          })
            .margin({ top: 6 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
  }

  build() {
    SonarPageLayout({
      options: this.layoutOptions(),
      content: this.buildProfileBody
    })
  }
}
