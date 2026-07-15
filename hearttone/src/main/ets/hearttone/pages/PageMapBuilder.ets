import { LoginPage } from './LoginPage';
import { AlbumDetailPage } from './AlbumDetailPage';
import { CacheSettingsPage } from './CacheSettingsPage';
import { ExportConfigPage } from './ExportConfigPage';
import { NowPlayingPage } from './NowPlayingPage';
import { MusicStatsPage } from './MusicStatsPage';
import { DataManagementPage } from './DataManagementPage';
import { PlaylistLibraryPage } from './PlaylistLibraryPage';
import { PlaylistImportPage } from './PlaylistImportPage';
import { PlaylistDetailPage } from './PlaylistDetailPage';
import { PlaylistTransferPage } from './PlaylistTransferPage';
import { PersonalizationSettingsPage } from './PersonalizationSettingsPage';
import { ServerSettingsContent } from '../components/settings/ServerSettingsContent';
import { SecondaryHdsDestination } from '../components/navigation/SecondaryHdsDestination';

@Builder
function buildServerSettingsContent() {
  ServerSettingsContent()
}

@Component
struct ServerNavPage {
  build() {
    SecondaryHdsDestination({
      title: '服务器',
      content: buildServerSettingsContent
    })
  }
}

@Builder
function buildCacheSettingsContent() {
  CacheSettingsPage()
}

@Builder
function buildExportConfigContent() {
  ExportConfigPage()
}

@Builder
function buildPersonalizationContent() {
  PersonalizationSettingsPage()
}

@Builder
function buildMusicStatsContent() {
  MusicStatsPage()
}

@Builder
function buildDataManagementContent() {
  DataManagementPage()
}

@Builder
function buildPlaylistLibraryContent() {
  PlaylistLibraryPage()
}

@Builder
function buildPlaylistImportContent() {
  PlaylistImportPage()
}

@Component
struct CacheSettingsNavPage {
  build() {
    SecondaryHdsDestination({
      title: '缓存设置',
      content: buildCacheSettingsContent
    })
  }
}

@Component
struct ExportConfigNavPage {
  build() {
    SecondaryHdsDestination({
      title: '备份与恢复',
      content: buildExportConfigContent
    })
  }
}

@Component
struct PersonalizationNavPage {
  build() {
    SecondaryHdsDestination({
      title: '个性化配置',
      content: buildPersonalizationContent
    })
  }
}

@Component
struct MusicStatsNavPage {
  build() {
    SecondaryHdsDestination({
      title: '音乐统计',
      contentVariant: 'hero',
      content: buildMusicStatsContent
    })
  }
}

@Component
struct DataManagementNavPage {
  build() {
    SecondaryHdsDestination({
      title: '数据管理',
      content: buildDataManagementContent
    })
  }
}

@Component
struct PlaylistLibraryNavPage {
  build() {
    SecondaryHdsDestination({
      title: '我的歌单',
      contentVariant: 'hero',
      content: buildPlaylistLibraryContent
    })
  }
}

@Component
struct PlaylistImportNavPage {
  build() {
    SecondaryHdsDestination({
      title: '新建歌单',
      content: buildPlaylistImportContent
    })
  }
}

@Builder
function buildUnknownPage(name: string) {
  Column() {
    Text(`未找到页面: ${name}`)
      .fontSize(16)
      .fontColor('#1C1C1E')
  }
  .width('100%')
  .height('100%')
  .justifyContent(FlexAlign.Center)
  .alignItems(HorizontalAlign.Center)
}

@Builder
export function PageMap(name: string) {
  if (name === 'LoginPage') {
    NavDestination() {
      LoginPage()
    }
    .hideTitleBar(true)
  } else if (name === 'AlbumDetailPage') {
    AlbumDetailPage()
  } else if (name === 'CacheSettingsPage') {
    CacheSettingsNavPage()
  } else if (name === 'ExportConfigPage') {
    ExportConfigNavPage()
  } else if (name === 'ServerPage') {
    ServerNavPage()
  } else if (name === 'PersonalizationPage') {
    PersonalizationNavPage()
  } else if (name === 'MusicStatsPage') {
    MusicStatsNavPage()
  } else if (name === 'DataManagementPage') {
    DataManagementNavPage()
  } else if (name === 'PlaylistLibraryPage') {
    PlaylistLibraryNavPage()
  } else if (name === 'PlaylistImportPage') {
    PlaylistImportNavPage()
  } else if (name === 'PlaylistDetailPage') {
    PlaylistDetailPage()
  } else if (name === 'PlaylistTransferPage') {
    PlaylistTransferPage()
  } else if (name === 'NowPlayingPage') {
    NavDestination() {
      NowPlayingPage()
    }
    .hideTitleBar(true)
  } else {
    NavDestination() {
      buildUnknownPage(name)
    }
    .hideTitleBar(true)
  }
}
