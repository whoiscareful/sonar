import { LibraryPage } from '../../pages/LibraryPage';
import { MusicPage } from '../../pages/MusicPage';
import { ProfilePage } from '../../pages/ProfilePage';

/** Tab 根页唯一 import 入口，避免 HdsTabsShell / FloatingTabBar 重复拉取同一依赖树 */
@Builder
export function buildMusicTabPage() {
  MusicPage()
}

@Builder
export function buildLibraryTabPage() {
  LibraryPage()
}

@Builder
export function buildProfileTabPage() {
  ProfilePage()
}
