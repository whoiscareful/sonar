import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { AuthStore } from '../auth/AuthStore';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { SecondaryButton } from '../components/buttons/SecondaryButton';
import { AppTextArea } from '../components/forms/AppTextArea';
import { AppTextInput } from '../components/forms/AppTextInput';
import { CardContainer } from '../components/layout/CardContainer';
import { CacheFileUtil } from '../common/CacheFileUtil';
import { ToastUtil } from '../common/ToastUtil';
import { ConfigCodecError, HeartToneConfigCodec } from '../settings/HeartToneConfigCodec';
import {
  UserDataExporter,
  UserDataExportOptions,
  UserDataExportResult
} from '../settings/UserDataExporter';
import {
  UserDataImporter,
  UserDataImportPackage,
  UserDataImportPreview,
  UserDataRestoreOptions,
  UserDataRestoreResult
} from '../settings/UserDataImporter';
import { UiTokens } from '../ui/tokens/UiTokens';

@Component
export struct ExportConfigPage {
  @State private exportPassword: string = '';
  @State private exportedBase64: string = '';
  @State private isGenerating: boolean = false;
  @State private errorMessage: string = '';
  @State private hasRememberedInfo: boolean = false;
  @State private includePlaylists: boolean = true;
  @State private includeListeningHistory: boolean = true;
  @State private includePreferences: boolean = true;
  @State private isExportingData: boolean = false;
  @State private dataExportStatus: string = '';
  @State private isImportingData: boolean = false;
  @State private hasImportPreview: boolean = false;
  @State private importExportedAt: string = '';
  @State private importAccountText: string = '';
  @State private importAccountMismatch: boolean = false;
  @State private importPlaylistCount: number = 0;
  @State private importSongCount: number = 0;
  @State private importListeningEventCount: number = 0;
  @State private importMatchingPlaylistCount: number = 0;
  @State private importCurrentPlaylistCount: number = 0;
  @State private importHasPlaylists: boolean = false;
  @State private importHasListeningHistory: boolean = false;
  @State private importHasPreferences: boolean = false;
  @State private restorePlaylists: boolean = false;
  @State private restoreListeningHistory: boolean = false;
  @State private restorePreferences: boolean = false;
  @State private replaceExistingData: boolean = false;
  @State private dataImportStatus: string = '';
  private importPackage: UserDataImportPackage | null = null;

  aboutToAppear(): void {
    void this.checkRememberedInfo();
  }

  private async checkRememberedInfo(): Promise<void> {
    const info = await AuthStore.getInstance().getRememberedLoginInfo();
    this.hasRememberedInfo =
      info.remoteServerUrl.trim().length > 0 &&
      info.username.trim().length > 0 &&
      info.password.length > 0;
  }

  private async generateConfig(): Promise<void> {
    if (this.isGenerating) {
      return;
    }
    if (!this.hasRememberedInfo) {
      this.errorMessage = '请在我的 > 服务器完成登录';
      return;
    }
    if (this.exportPassword.trim().length === 0) {
      this.errorMessage = '请设置配置密码';
      return;
    }
    this.isGenerating = true;
    this.errorMessage = '';
    try {
      const info = await AuthStore.getInstance().getRememberedLoginInfo();
      this.exportedBase64 = await HeartToneConfigCodec.exportConfig(info, this.exportPassword);
    } catch (err) {
      if (err instanceof ConfigCodecError) {
        this.errorMessage = err.message;
      } else {
        this.errorMessage = `导出失败: ${(err as Error).message}`;
      }
    } finally {
      this.isGenerating = false;
    }
  }

  private async copyToClipboard(): Promise<void> {
    if (this.exportedBase64.length === 0) {
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN, this.exportedBase64);
      await pasteboard.getSystemPasteboard().setData(data);
      ToastUtil.show(this, '已复制到剪贴板，请妥善保管');
    } catch (_err) {
      ToastUtil.show(this, '复制失败');
    }
  }

  private hasDataSelection(): boolean {
    return this.includePlaylists || this.includeListeningHistory || this.includePreferences;
  }

  private async exportUserData(): Promise<void> {
    if (this.isExportingData || !this.hasDataSelection()) {
      return;
    }
    this.isExportingData = true;
    this.dataExportStatus = '';
    try {
      const options: UserDataExportOptions = {
        includePlaylists: this.includePlaylists,
        includeListeningHistory: this.includeListeningHistory,
        includePreferences: this.includePreferences
      };
      const result: UserDataExportResult = await UserDataExporter.export(options);
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const stamp: string = new Date().toISOString().substring(0, 10);
      const uris: string[] = await documentPicker.save({
        newFileNames: [`HeartTone-个人数据-${stamp}.json`]
      });
      if (uris.length === 0) {
        return;
      }
      ExportConfigPage.writeText(uris[0], result.json);
      this.dataExportStatus = `已导出 ${result.summary.playlistCount} 个歌单、` +
        `${result.summary.songCount} 首歌、${result.summary.listeningEventCount} 条听歌记录`;
      ToastUtil.show(this, '个人数据副本已保存');
    } catch (err) {
      ToastUtil.show(this, `数据导出失败：${(err as Error).message}`);
    } finally {
      this.isExportingData = false;
    }
  }

  private async pickUserDataFile(): Promise<void> {
    if (this.isImportingData) {
      return;
    }
    this.isImportingData = true;
    this.dataImportStatus = '';
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await documentPicker.select({
        fileSuffixFilters: ['HeartTone 数据副本|.json'],
        maxSelectNumber: 1
      });
      if (uris.length === 0) {
        return;
      }
      const json: string = ExportConfigPage.readText(uris[0]);
      const importPackage: UserDataImportPackage = await UserDataImporter.inspect(json);
      this.applyImportPreview(importPackage);
      ToastUtil.show(this, '副本已读取，请确认恢复内容');
    } catch (err) {
      ToastUtil.show(this, `无法读取数据副本：${(err as Error).message}`);
    } finally {
      this.isImportingData = false;
    }
  }

  private applyImportPreview(importPackage: UserDataImportPackage): void {
    const preview: UserDataImportPreview = importPackage.preview;
    this.importPackage = importPackage;
    this.hasImportPreview = true;
    this.importExportedAt = preview.exportedAt;
    this.importAccountText = preview.accountText;
    this.importAccountMismatch = preview.accountMismatch;
    this.importPlaylistCount = preview.playlistCount;
    this.importSongCount = preview.songCount;
    this.importListeningEventCount = preview.listeningEventCount;
    this.importMatchingPlaylistCount = preview.matchingPlaylistCount;
    this.importCurrentPlaylistCount = preview.currentPlaylistCount;
    this.importHasPlaylists = preview.hasPlaylists;
    this.importHasListeningHistory = preview.hasListeningHistory;
    this.importHasPreferences = preview.hasPreferences;
    this.restorePlaylists = preview.hasPlaylists;
    this.restoreListeningHistory = preview.hasListeningHistory;
    this.restorePreferences = preview.hasPreferences;
  }

  private hasRestoreSelection(): boolean {
    return this.restorePlaylists || this.restoreListeningHistory || this.restorePreferences;
  }

  private async restoreUserData(): Promise<void> {
    if (this.isImportingData || this.importPackage === null || !this.hasRestoreSelection()) {
      return;
    }
    const modeText: string = this.replaceExistingData ?
      '所选类型的当前本地数据会被副本替换。' :
      '副本会与当前数据合并，相同稳定 ID 的内容以副本为准。';
    const accountText: string = this.importAccountMismatch ?
      '\n注意：副本账号与当前账号不同，数据将恢复到当前账号。' : '';
    const confirm = await this.getUIContext().getPromptAction().showDialog({
      title: this.replaceExistingData ? '覆盖所选数据？' : '合并所选数据？',
      message: `${modeText}${accountText}`,
      buttons: [
        { text: '取消', color: '#7A7F8A' },
        { text: '开始恢复', color: '#3A6FF7' }
      ]
    });
    if (confirm.index !== 1) {
      return;
    }
    this.isImportingData = true;
    this.dataImportStatus = '';
    try {
      const options: UserDataRestoreOptions = {
        includePlaylists: this.restorePlaylists,
        includeListeningHistory: this.restoreListeningHistory,
        includePreferences: this.restorePreferences,
        replaceExisting: this.replaceExistingData
      };
      const result: UserDataRestoreResult = await UserDataImporter.restore(this.importPackage, options);
      this.dataImportStatus = `已恢复 ${result.playlistCount} 个歌单、` +
        `${result.listeningEventCount} 条听歌记录` +
        (result.preferencesRestored ? '和应用偏好' : '');
      ToastUtil.show(this, '个人数据恢复完成');
    } catch (err) {
      ToastUtil.show(this, `数据恢复失败：${(err as Error).message}`);
    } finally {
      this.isImportingData = false;
    }
  }

  private importTimeText(): string {
    if (this.importExportedAt.length < 10) {
      return this.importExportedAt;
    }
    return this.importExportedAt.substring(0, 10);
  }

  private static writeText(uri: string, text: string): void {
    const file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE);
    try {
      fileIo.truncateSync(file.fd, 0);
      const content: ArrayBuffer = CacheFileUtil.utf8ToBuffer(text);
      fileIo.writeSync(file.fd, content, { offset: 0, length: content.byteLength });
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static readText(uri: string): string {
    const size: number = fileIo.statSync(uri).size;
    if (size <= 0) {
      throw new Error('文件内容为空');
    }
    if (size > 10 * 1024 * 1024) {
      throw new Error('文件超过 10 MB，无法作为数据副本读取');
    }
    const file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const content: ArrayBuffer = new ArrayBuffer(size);
      fileIo.readSync(file.fd, content);
      return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(content));
    } finally {
      fileIo.closeSync(file);
    }
  }

  @Builder
  private importMetric(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
      Text(label)
        .fontSize(10)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
    .borderRadius(8)
  }

  @Builder
  private importModeOption(replace: boolean, title: string, subtitle: string) {
    Button() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.replaceExistingData === replace ?
            UiTokens.COLOR_TEXT_ON_BRAND : UiTokens.COLOR_TEXT_PRIMARY)
        Text(subtitle)
          .fontSize(9)
          .fontColor(this.replaceExistingData === replace ?
            UiTokens.COLOR_TEXT_ON_BRAND : UiTokens.COLOR_TEXT_TERTIARY)
      }
    }
    .layoutWeight(1)
    .height(46)
    .borderRadius(8)
    .backgroundColor(this.replaceExistingData === replace ?
      UiTokens.COLOR_PRIMARY : UiTokens.COLOR_PRIMARY_SOFT_BG)
    .onClick(() => {
      this.replaceExistingData = replace;
    })
  }

  @Builder
  private restoreOption(title: string, subtitle: string, selected: boolean,
    onChange: (selected: boolean) => void) {
    Row({ space: 10 }) {
      Checkbox({ name: `restore-${title}`, group: 'user-data-restore' })
        .select(selected)
        .selectedColor(UiTokens.COLOR_PRIMARY)
        .onChange((value: boolean) => {
          onChange(value);
        })
      Column({ space: 2 }) {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(subtitle)
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
  private exportOption(title: string, subtitle: string, selected: boolean,
    onChange: (selected: boolean) => void) {
    Row({ space: 10 }) {
      Checkbox({ name: title, group: 'user-data-export' })
        .select(selected)
        .selectedColor(UiTokens.COLOR_PRIMARY)
        .onChange((value: boolean) => {
          onChange(value);
        })
      Column({ space: 2 }) {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(subtitle)
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

  build() {
    Column({ space: UiTokens.SECTION_GAP }) {
      CardContainer() {
        Column({ space: 10 }) {
          Text('服务器登录配置')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text('加密导出服务器地址、账号和密码，可在登录页恢复。')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)

          if (!this.hasRememberedInfo) {
            Text('请在我的 > 服务器完成登录')
              .fontSize(13)
              .fontColor(UiTokens.COLOR_ERROR)
          }

          AppTextInput({
            text: this.exportPassword,
            placeholder: '配置密码（必填）',
            isPassword: true,
            onValueChange: (value: string) => {
              this.exportPassword = value;
            }
          })

          PrimaryButton({
            text: '生成登录配置',
            loading: this.isGenerating,
            isEnabled: this.hasRememberedInfo && this.exportPassword.trim().length > 0 && !this.isGenerating,
            onPressed: () => {
              void this.generateConfig();
            }
          })

          if (this.exportedBase64.length > 0) {
            AppTextArea({
              text: this.exportedBase64,
              placeholder: '',
              areaHeight: 120,
              readOnly: true,
              onValueChange: (_value: string) => {
              }
            })
            SecondaryButton({
              text: '复制到剪贴板',
              onPressed: () => {
                void this.copyToClipboard();
              }
            })
            Text('配置含登录密码，请勿分享给不可信的人')
              .fontSize(11)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          }

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor(UiTokens.COLOR_ERROR)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      CardContainer() {
        Column({ space: 6 }) {
          Text('导出个人数据')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text('保存为 JSON 文件，不包含登录密码、缓存文件和本地图片。')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)

          this.exportOption('本地歌单', '歌单名称、歌曲信息和专辑封面引用', this.includePlaylists,
            (selected: boolean): void => { this.includePlaylists = selected; })
          this.exportOption('听歌记录', '近 90 天有效播放记录与统计字段', this.includeListeningHistory,
            (selected: boolean): void => { this.includeListeningHistory = selected; })
          this.exportOption('应用偏好', '列表模式、外观参数和缓存设置', this.includePreferences,
            (selected: boolean): void => { this.includePreferences = selected; })

          PrimaryButton({
            text: '保存个人数据副本',
            loading: this.isExportingData,
            isEnabled: this.hasDataSelection() && !this.isExportingData,
            onPressed: () => {
              void this.exportUserData();
            }
          })

          if (this.dataExportStatus.length > 0) {
            Text(this.dataExportStatus)
              .fontSize(11)
              .fontColor(UiTokens.COLOR_SUCCESS)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      CardContainer() {
        Column({ space: 10 }) {
          Text('从数据副本恢复')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text('选择 HeartTone JSON 文件后先预览，确认前不会修改当前数据。')
            .width('100%')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)

          Button(this.isImportingData ? '正在处理' :
            (this.hasImportPreview ? '重新选择数据副本' : '选择数据副本'))
            .width('100%')
            .height(42)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_PRIMARY)
            .backgroundColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .borderRadius(9)
            .enabled(!this.isImportingData)
            .onClick(() => {
              void this.pickUserDataFile();
            })

          if (this.hasImportPreview) {
            Divider().color(UiTokens.COLOR_CARD_BORDER)
            Row({ space: 6 }) {
              this.importMetric(this.importPlaylistCount.toString(), '歌单')
              this.importMetric(this.importSongCount.toString(), '歌曲')
              this.importMetric(this.importListeningEventCount.toString(), '听歌记录')
            }
            .width('100%')

            Column({ space: 3 }) {
              Text(`导出日期：${this.importTimeText()}`)
                .fontSize(11)
                .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              Text(`来源账号：${this.importAccountText}`)
                .width('100%')
                .fontSize(11)
                .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            if (this.importAccountMismatch) {
              Text('副本账号与当前账号不同，恢复的数据将写入当前账号。')
                .width('100%')
                .fontSize(11)
                .fontColor(UiTokens.COLOR_WARNING)
                .padding(8)
                .borderRadius(8)
                .backgroundColor(UiTokens.COLOR_WARNING_SOFT_BG)
            }

            Row({ space: 6 }) {
              this.importModeOption(false, '合并',
                `${this.importMatchingPlaylistCount} 个同 ID 歌单将更新`)
              this.importModeOption(true, '覆盖',
                `替换当前 ${this.importCurrentPlaylistCount} 个歌单`)
            }
            .width('100%')

            if (this.importHasPlaylists) {
              this.restoreOption('恢复歌单', `${this.importPlaylistCount} 个歌单、${this.importSongCount} 首歌曲`,
                this.restorePlaylists,
                (selected: boolean): void => { this.restorePlaylists = selected; })
            }
            if (this.importHasListeningHistory) {
              this.restoreOption('恢复听歌记录', `${this.importListeningEventCount} 条有效记录`,
                this.restoreListeningHistory,
                (selected: boolean): void => { this.restoreListeningHistory = selected; })
            }
            if (this.importHasPreferences) {
              this.restoreOption('恢复应用偏好', '列表模式、远程外观与缓存设置',
                this.restorePreferences,
                (selected: boolean): void => { this.restorePreferences = selected; })
            }

            PrimaryButton({
              text: this.replaceExistingData ? '确认覆盖所选数据' : '确认合并所选数据',
              loading: this.isImportingData,
              isEnabled: this.hasRestoreSelection() && !this.isImportingData,
              onPressed: () => {
                void this.restoreUserData();
              }
            })

            if (this.dataImportStatus.length > 0) {
              Text(this.dataImportStatus)
                .fontSize(11)
                .fontColor(UiTokens.COLOR_SUCCESS)
            }
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
  }
}
