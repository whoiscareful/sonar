import { pasteboard } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { Song } from '../api/SubsonicTypes';
import { CardContainer } from '../components/layout/CardContainer';
import { PlaylistImageOcr } from '../domain/playlist/PlaylistImageOcr';
import {
  PlatformPlaylistImporter,
  PlatformPlaylistImportResult
} from '../domain/playlist/PlatformPlaylistImporter';
import {
  MatchedImportSong,
  PlaylistImportMatcher,
  PlaylistImportMatchResult,
  SuggestedImportSong
} from '../domain/playlist/PlaylistImportMatcher';
import {
  ImportSongCandidate,
  PlaylistImportMode,
  PlaylistImportParser
} from '../domain/playlist/PlaylistImportParser';
import { UserPlaylistStore } from '../settings/UserPlaylistStore';
import { UiTokens } from '../ui/tokens/UiTokens';

const AI_IMAGE_PROMPT: string = '请分析这张音乐歌单截图，只提取截图中真实存在的歌曲。' +
  '忽略状态栏、导航、按钮、播放时长、专辑名称、推荐文案和其他界面文字。' +
  '每首歌曲单独一行，严格使用“歌名 - 歌手”格式。' +
  '不要返回 Markdown、JSON、说明或序号；无法确认歌手时只返回歌名，不要猜测。';

@Component
export struct PlaylistImportPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State private modeIndex: number = 0;
  @State private playlistName: string = '';
  @State private sourceText: string = '';
  @State private matched: MatchedImportSong[] = [];
  @State private suggestions: SuggestedImportSong[] = [];
  @State private selectedSuggestionKeys: string[] = [];
  @State private unmatched: ImportSongCandidate[] = [];
  @State private busy: boolean = false;
  @State private progressText: string = '';
  @State private sourcePlatformName: string = '';
  private readonly matcher: PlaylistImportMatcher = new PlaylistImportMatcher();

  private modeTitle(index: number): string {
    if (index === 1) {
      return '图片识别';
    }
    if (index === 2) {
      return 'AI 导入';
    }
    return '链接导入';
  }

  private placeholder(): string {
    if (this.modeIndex === 2) {
      return '例如：周杰伦的晴天、陈奕迅的十年、孙燕姿的遇见';
    }
    if (this.modeIndex === 1) {
      return '选择歌单截图后，识别出的文字会显示在这里，也可以手动修正';
    }
    return '粘贴歌单分享链接，例如网易云音乐或华为音乐的公开歌单链接';
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (_err) {
    }
  }

  private selectMode(index: number): void {
    if (this.busy || this.modeIndex === index) {
      return;
    }
    this.modeIndex = index;
    this.sourceText = '';
    this.matched = [];
    this.suggestions = [];
    this.selectedSuggestionKeys = [];
    this.unmatched = [];
    this.progressText = '';
    this.sourcePlatformName = '';
  }

  private async pickImage(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.progressText = '正在识别图片文字';
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const selection: photoAccessHelper.PhotoSelectResult = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (selection.photoUris.length === 0) {
        return;
      }
      this.sourceText = await PlaylistImageOcr.recognize(selection.photoUris[0]);
      if (this.sourceText.trim().length === 0) {
        this.showToast('图片中没有识别到文字');
      } else {
        this.showToast('文字识别完成，请检查后开始匹配');
      }
    } catch (err) {
      this.showToast(`图片识别失败：${(err as Error).message}`);
    } finally {
      this.busy = false;
      this.progressText = '';
    }
  }

  private async copyAiPrompt(): Promise<void> {
    try {
      const pasteData: pasteboard.PasteData = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN, AI_IMAGE_PROMPT);
      await pasteboard.getSystemPasteboard().setData(pasteData);
      this.showToast('AI 提示词已复制');
    } catch (_err) {
      this.showToast('复制提示词失败');
    }
  }

  private async matchSongs(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.matched = [];
    this.suggestions = [];
    this.selectedSuggestionKeys = [];
    this.unmatched = [];
    try {
      let candidates: ImportSongCandidate[] = [];
      if (this.modeIndex === 0) {
        this.progressText = '正在读取分享链接';
        const imported: PlatformPlaylistImportResult =
          await PlatformPlaylistImporter.importFromShareText(this.sourceText);
        candidates = imported.candidates;
        this.sourcePlatformName = imported.platformName;
        if (this.playlistName.trim().length === 0) {
          this.playlistName = imported.playlistName;
        }
      } else {
        const parserMode: PlaylistImportMode = this.modeIndex === 2 ? 'ai' : 'platform';
        candidates = PlaylistImportParser.parse(this.sourceText, parserMode);
      }
      if (candidates.length === 0) {
        throw new Error('没有识别到可导入的歌曲');
      }
      const result: PlaylistImportMatchResult = await this.matcher.match(
        candidates,
        (completed: number, total: number): void => {
          this.progressText = `正在匹配 ${completed}/${total}`;
        }
      );
      this.matched = result.matched;
      this.suggestions = result.suggestions;
      this.unmatched = result.unmatched;
      if (this.playlistName.trim().length === 0) {
        this.playlistName = `${this.modeTitle(this.modeIndex)}歌单`;
      }
      const sourceLabel: string = this.sourcePlatformName.length > 0 ? `${this.sourcePlatformName}：` : '';
      this.showToast(`${sourceLabel}自动匹配 ${this.matched.length} 首，待确认 ${this.suggestions.length} 首`);
    } catch (err) {
      this.showToast(`导入失败：${(err as Error).message}`);
    } finally {
      this.busy = false;
      this.progressText = '';
    }
  }

  private suggestionKey(suggestionIndex: number, songId: string): string {
    return `${suggestionIndex}:${songId}`;
  }

  private isSuggestionSelected(suggestionIndex: number, songId: string): boolean {
    return this.selectedSuggestionKeys.indexOf(this.suggestionKey(suggestionIndex, songId)) >= 0;
  }

  private updateSuggestionSelection(suggestionIndex: number, songId: string, selected: boolean): void {
    const prefix: string = `${suggestionIndex}:`;
    const next: string[] = this.selectedSuggestionKeys.filter((key: string): boolean => !key.startsWith(prefix));
    if (selected) {
      next.push(this.suggestionKey(suggestionIndex, songId));
    }
    this.selectedSuggestionKeys = next;
  }

  private selectedSuggestionCount(): number {
    return this.selectedSuggestionKeys.length;
  }

  private selectedSongCount(): number {
    return this.matched.length + this.selectedSuggestionCount();
  }

  private async savePlaylist(): Promise<void> {
    if (this.busy || this.selectedSongCount() === 0) {
      return;
    }
    const name: string = this.playlistName.trim();
    if (name.length === 0) {
      this.showToast('请输入歌单名称');
      return;
    }
    this.busy = true;
    try {
      const songs: Song[] = [];
      const songIds: Set<string> = new Set<string>();
      for (let i: number = 0; i < this.matched.length; i++) {
        if (!songIds.has(this.matched[i].song.id)) {
          songIds.add(this.matched[i].song.id);
          songs.push(this.matched[i].song);
        }
      }
      for (let i: number = 0; i < this.suggestions.length; i++) {
        const options: MatchedImportSong[] = this.suggestions[i].options;
        for (let j: number = 0; j < options.length; j++) {
          if (this.isSuggestionSelected(i, options[j].song.id) && !songIds.has(options[j].song.id)) {
            songIds.add(options[j].song.id);
            songs.push(options[j].song);
          }
        }
      }
      await UserPlaylistStore.getInstance().create(name, songs);
      this.showToast('歌单已保存');
      this.appPathStack.pop();
    } catch (err) {
      this.showToast(`保存失败：${(err as Error).message}`);
    } finally {
      this.busy = false;
    }
  }

  private async createEmptyPlaylist(): Promise<void> {
    if (this.busy) {
      return;
    }
    const name: string = this.playlistName.trim();
    if (name.length === 0) {
      this.showToast('请先输入歌单名称');
      return;
    }
    this.busy = true;
    try {
      const songs: Song[] = [];
      await UserPlaylistStore.getInstance().create(name, songs);
      this.showToast('空歌单已创建');
      this.appPathStack.pop();
    } catch (err) {
      this.showToast(`创建失败：${(err as Error).message}`);
    } finally {
      this.busy = false;
    }
  }

  @Builder
  private modeOption(index: number) {
    Text(this.modeTitle(index))
      .layoutWeight(1)
      .height(34)
      .textAlign(TextAlign.Center)
      .fontSize(12)
      .fontWeight(this.modeIndex === index ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.modeIndex === index ? UiTokens.COLOR_TEXT_ON_BRAND : UiTokens.COLOR_TEXT_SECONDARY)
      .backgroundColor(this.modeIndex === index ? UiTokens.COLOR_PRIMARY : Color.Transparent)
      .borderRadius(9)
      .onClick(() => {
        this.selectMode(index);
      })
  }

  @Builder
  private matchedRow(item: MatchedImportSong) {
    Row({ space: 10 }) {
      Column() {
        Text('✓')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_SUCCESS)
      }
      .width(26)
      .height(26)
      .justifyContent(FlexAlign.Center)
      .borderRadius(8)
      .backgroundColor(UiTokens.COLOR_SUCCESS_SOFT_BG)
      Column({ space: 2 }) {
        Text(item.song.title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${item.song.artist} · ${item.song.album}`)
          .fontSize(10)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private suggestionOption(suggestionIndex: number, item: MatchedImportSong) {
    Row({ space: 8 }) {
      Checkbox({ name: this.suggestionKey(suggestionIndex, item.song.id) })
        .select(this.isSuggestionSelected(suggestionIndex, item.song.id))
        .selectedColor(UiTokens.COLOR_PRIMARY)
        .width(22)
        .height(22)
        .onChange((selected: boolean) => {
          this.updateSuggestionSelection(suggestionIndex, item.song.id, selected);
        })
      Column({ space: 2 }) {
        Text(item.song.title)
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${item.song.artist} · ${item.song.album}`)
          .width('100%')
          .fontSize(10)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(46)
    .padding({ left: 9, right: 9 })
    .borderRadius(8)
    .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
  }

  @Builder
  private suggestionBlock(item: SuggestedImportSong, suggestionIndex: number) {
    Column({ space: 6 }) {
      Text(item.candidate.artist.length > 0 ?
        `${item.candidate.title} - ${item.candidate.artist}` : item.candidate.title)
        .width('100%')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      ForEach(item.options, (option: MatchedImportSong) => {
        this.suggestionOption(suggestionIndex, option)
      }, (option: MatchedImportSong) => option.song.id)
    }
    .width('100%')
    .padding({ top: 5, bottom: 5 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: UiTokens.SECTION_GAP }) {
      Row() {
        this.modeOption(0)
        this.modeOption(1)
        this.modeOption(2)
      }
      .width('100%')
      .padding(2)
      .borderRadius(11)
      .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)

      CardContainer() {
        Column({ space: 12 }) {
          Text('歌单名称')
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          TextInput({ text: this.playlistName, placeholder: '输入歌单名称' })
            .width('100%')
            .height(42)
            .fontSize(13)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .borderRadius(11)
            .onChange((value: string) => {
              this.playlistName = value;
            })

          Button('仅创建空歌单')
            .width('100%')
            .height(38)
            .fontSize(12)
            .fontColor(UiTokens.COLOR_PRIMARY)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .borderRadius(10)
            .enabled(!this.busy)
            .onClick(() => {
              void this.createEmptyPlaylist();
            })

          if (this.modeIndex === 1) {
            Button() {
              Row({ space: 7 }) {
                Image($r('app.media.ic_playlist_add'))
                  .width(17)
                  .height(17)
                  .fillColor(UiTokens.COLOR_PRIMARY)
                Text('选择歌单截图')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(UiTokens.COLOR_PRIMARY)
              }
            }
            .width('100%')
            .height(42)
            .borderRadius(11)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .enabled(!this.busy)
            .onClick(() => {
              void this.pickImage();
            })
          }

          if (this.modeIndex === 2) {
            Text('可将歌单截图发送给任意视觉 AI，再把返回内容粘贴到下方。')
              .width('100%')
              .fontSize(10)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            Text(AI_IMAGE_PROMPT)
              .width('100%')
              .fontSize(10)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
              .padding(8)
              .borderRadius(8)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            Button('复制 AI 提示词')
              .width('100%')
              .height(36)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(UiTokens.COLOR_PRIMARY)
              .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
              .borderRadius(9)
              .enabled(!this.busy)
              .onClick(() => {
                void this.copyAiPrompt();
              })
          }

          if (this.modeIndex === 0) {
            Text(`支持：${PlatformPlaylistImporter.supportedPlatformText()}`)
              .width('100%')
              .fontSize(11)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            Text('仅支持无需登录即可打开的公开歌单；私密、失效或平台限制访问的链接无法导入。')
              .width('100%')
              .fontSize(10)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          }

          TextArea({ text: this.sourceText, placeholder: this.placeholder() })
            .width('100%')
            .height(148)
            .fontSize(13)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .borderRadius(11)
            .onChange((value: string) => {
              this.sourceText = value;
            })

          Button(this.busy ? (this.progressText.length > 0 ? this.progressText : '处理中') :
            (this.modeIndex === 0 ? '读取链接并匹配曲库' : '识别并匹配曲库'))
            .width('100%')
            .height(42)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
            .backgroundColor(this.busy ? UiTokens.COLOR_PRIMARY_DISABLED_BG : UiTokens.COLOR_PRIMARY)
            .borderRadius(11)
            .enabled(!this.busy)
            .onClick(() => {
              void this.matchSongs();
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      if (this.matched.length > 0 || this.suggestions.length > 0 || this.unmatched.length > 0) {
        CardContainer() {
          Column({ space: 8 }) {
            Row() {
              Text('匹配结果')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
              Blank()
              Text(`${this.matched.length} 自动 · ${this.suggestions.length} 待确认 · ${this.unmatched.length} 无结果`)
                .fontSize(10)
                .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
            }
            .width('100%')
            ForEach(this.matched, (item: MatchedImportSong) => {
              this.matchedRow(item)
            }, (item: MatchedImportSong) => item.song.id)
            if (this.suggestions.length > 0) {
              Divider().color(UiTokens.COLOR_CARD_BORDER)
              Text('需要确认')
                .width('100%')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(UiTokens.COLOR_WARNING)
              Text('歌名未完全一致，不会自动加入。每首可选择一个候选，也可以不选。')
                .width('100%')
                .fontSize(10)
                .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
              ForEach(this.suggestions, (item: SuggestedImportSong, index: number) => {
                this.suggestionBlock(item, index)
              }, (item: SuggestedImportSong) => item.candidate.sourceText)
            }
            if (this.unmatched.length > 0) {
              Divider().color(UiTokens.COLOR_CARD_BORDER)
              Text('无候选结果')
                .width('100%')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(UiTokens.COLOR_WARNING)
              ForEach(this.unmatched, (item: ImportSongCandidate) => {
                Text(item.artist.length > 0 ? `${item.title} - ${item.artist}` : item.title)
                  .width('100%')
                  .fontSize(11)
                  .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .padding({ top: 3, bottom: 3 })
              }, (item: ImportSongCandidate) => item.sourceText)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        Button(`保存歌单（${this.selectedSongCount()} 首）`)
          .width('100%')
          .height(46)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_ON_BRAND)
          .backgroundColor(this.selectedSongCount() > 0 && !this.busy ? UiTokens.COLOR_ACTION_BG :
            UiTokens.COLOR_PRIMARY_DISABLED_BG)
          .borderRadius(13)
          .enabled(this.selectedSongCount() > 0 && !this.busy)
          .onClick(() => {
            void this.savePlaylist();
          })
      }
    }
    .width('100%')
  }
}
