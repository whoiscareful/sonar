import { SonicApiEntryModule } from '../../view/SonicApiEntryModule';
import { CardContainer } from '../layout/CardContainer';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct ServerSettingsContent {
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInServer') loggedInServer: string = '';
  @StorageLink('loggedInEndpoint') loggedInEndpoint: string = 'remote';
  @StorageLink('networkType') networkType: string = 'none';

  private describeNetworkType(): string {
    switch (this.networkType) {
      case 'wifi':
        return 'WIFI';
      case 'cellular':
        return '蜂窝移动网络';
      case 'none':
        return '无网络';
      default:
        return '其他网络';
    }
  }

  @LocalBuilder
  buildConnectionStatusCard() {
    Column({ space: 8 }) {
      Text('连接状态')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
      Text(this.isLoggedIn ? '已登录服务器' : '未登录')
        .fontSize(13)
        .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
      if (this.isLoggedIn) {
        Text(`${this.loggedInServer} · ${this.loggedInEndpoint === 'local' ? '本地' : '远程'}`)
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      Text(`当前网络：${this.describeNetworkType()}`)
        .fontSize(12)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: UiTokens.SECTION_GAP }) {
      SonicApiEntryModule()

      CardContainer() {
        this.buildConnectionStatusCard()
      }
    }
    .width('100%')
  }
}
