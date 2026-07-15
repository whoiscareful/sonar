import { UIContext } from '@kit.ArkUI';
import promptAction from '@ohos.promptAction';
import { Song } from '../../api/SubsonicTypes';
import { UserPlaylist, UserPlaylistStore } from '../../settings/UserPlaylistStore';

export interface AddToUserPlaylistResult {
  added: boolean;
  message: string;
}

export class UserPlaylistPicker {
  static async addSong(uiContext: UIContext, song: Song): Promise<AddToUserPlaylistResult> {
    const store: UserPlaylistStore = UserPlaylistStore.getInstance();
    await store.ensureReady();
    const allPlaylists: UserPlaylist[] = store.list();
    if (allPlaylists.length === 0) {
      return UserPlaylistPicker.result(false, '请先在“我的歌单”中新建歌单');
    }
    const visibleCount: number = Math.min(6, allPlaylists.length);
    const buttons: [promptAction.Button, promptAction.Button?, promptAction.Button?,
      promptAction.Button?, promptAction.Button?, promptAction.Button?] = [
      { text: `${allPlaylists[0].name}（${allPlaylists[0].songs.length} 首）`, color: '#1C1C1E' }
    ];
    for (let i: number = 1; i < visibleCount; i++) {
      buttons.push({ text: `${allPlaylists[i].name}（${allPlaylists[i].songs.length} 首）`, color: '#1C1C1E' });
    }
    const response: promptAction.ActionMenuSuccessResponse = await uiContext.getPromptAction().showActionMenu({
      title: `添加「${song.title}」到歌单`,
      buttons: buttons
    });
    if (response.index < 0 || response.index >= visibleCount) {
      return UserPlaylistPicker.result(false, '已取消');
    }
    const target: UserPlaylist = allPlaylists[response.index];
    const added: number = await store.addSongs(target.id, [song]);
    return added > 0 ?
      UserPlaylistPicker.result(true, `已添加到「${target.name}」`) :
      UserPlaylistPicker.result(false, `「${target.name}」中已有这首歌`);
  }

  private static result(added: boolean, message: string): AddToUserPlaylistResult {
    const value: AddToUserPlaylistResult = { added: added, message: message };
    return value;
  }
}
