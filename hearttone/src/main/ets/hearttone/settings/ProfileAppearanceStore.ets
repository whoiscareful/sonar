import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { Logger } from '../common/Logger';
import { CacheFileUri } from '../common/CacheFileUri';
import { CacheFileUtil } from '../common/CacheFileUtil';
import { MusicTagWebOpenApi } from '../enhanced/MusicTagWebOpenApi';

const STORE_NAME: string = 'hearttone_profile_appearance';
const KEY_AVATAR_PATH: string = 'avatar_path';
const KEY_COVER_PATH: string = 'cover_path';
const KEY_RANDOM_IMAGE_API: string = 'random_image_api';
const KEY_BACKGROUND_BLUR: string = 'background_blur';
const KEY_BACKGROUND_MASK: string = 'background_mask';
const DOMESTIC_IMAGE_API_BASE: string = 'https://api.anosu.top/img/';
const FOREIGN_IMAGE_API_BASE: string = 'https://moe.jitsu.top/img/';
const DEFAULT_RANDOM_IMAGE_API: string = DOMESTIC_IMAGE_API_BASE;
const DEFAULT_BACKGROUND_IMAGE_API: string = `${DOMESTIC_IMAGE_API_BASE}?sort=mp`;

export interface AppearanceUpdateResult {
  uri: string;
  synced: boolean;
}

/** 个人页图片本地持久化；API Provider 可选，不与 Subsonic 播放认证耦合。 */
export class ProfileAppearanceStore {
  private static instance: ProfileAppearanceStore | null = null;
  private store: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private provider: MusicTagWebOpenApi | null = null;
  private avatarPath: string = '';
  private coverPath: string = '';
  private randomImageApi: string = DEFAULT_RANDOM_IMAGE_API;
  private backgroundBlurValue: number = 0;
  private backgroundMaskValue: number = 0.32;

  private constructor() {
  }

  static getInstance(): ProfileAppearanceStore {
    if (ProfileAppearanceStore.instance === null) {
      ProfileAppearanceStore.instance = new ProfileAppearanceStore();
    }
    return ProfileAppearanceStore.instance;
  }

  configureProvider(provider: MusicTagWebOpenApi | null): void {
    this.provider = provider;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store === null) {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
      this.avatarPath = (await this.store.get(KEY_AVATAR_PATH, '')) as string;
      this.coverPath = (await this.store.get(KEY_COVER_PATH, '')) as string;
      this.randomImageApi = (await this.store.get(KEY_RANDOM_IMAGE_API, DEFAULT_RANDOM_IMAGE_API)) as string;
      const migratedAvatarPath: string = this.normalizeBuiltInApiUri(this.avatarPath, true);
      const migratedCoverPath: string = this.normalizeBuiltInApiUri(this.coverPath, false);
      const migratedRandomImageApi: string = this.normalizeBuiltInApiUri(this.randomImageApi, true);
      if (migratedAvatarPath !== this.avatarPath || migratedCoverPath !== this.coverPath ||
        migratedRandomImageApi !== this.randomImageApi) {
        this.avatarPath = migratedAvatarPath;
        this.coverPath = migratedCoverPath;
        this.randomImageApi = migratedRandomImageApi;
        await this.store.put(KEY_AVATAR_PATH, this.avatarPath);
        await this.store.put(KEY_COVER_PATH, this.coverPath);
        await this.store.put(KEY_RANDOM_IMAGE_API, this.randomImageApi);
        await this.store.flush();
      }
      this.backgroundBlurValue = (await this.store.get(KEY_BACKGROUND_BLUR, 0)) as number;
      this.backgroundMaskValue = (await this.store.get(KEY_BACKGROUND_MASK, 0.32)) as number;
      this.publish();
    }
  }

  avatarUri(): string {
    return this.resolveImageUri(this.avatarPath);
  }

  coverUri(): string {
    return this.resolveImageUri(this.coverPath);
  }

  randomApiUrl(): string {
    return this.randomImageApi.length > 0 ? this.randomImageApi : DEFAULT_RANDOM_IMAGE_API;
  }

  defaultAvatarApiUrl(): string {
    return DEFAULT_RANDOM_IMAGE_API;
  }

  defaultBackgroundApiUrl(): string {
    return DEFAULT_BACKGROUND_IMAGE_API;
  }

  domesticImageApiUrl(): string {
    return DOMESTIC_IMAGE_API_BASE;
  }

  foreignImageApiUrl(): string {
    return FOREIGN_IMAGE_API_BASE;
  }

  backgroundBlur(): number {
    return this.backgroundBlurValue;
  }

  backgroundMask(): number {
    return this.backgroundMaskValue;
  }

  async updateAvatar(sourceUri: string): Promise<AppearanceUpdateResult> {
    return await this.updateImage(sourceUri, true);
  }

  async updateCover(sourceUri: string): Promise<AppearanceUpdateResult> {
    return await this.updateImage(sourceUri, false);
  }

  async updateInterfaceBackground(sourceUri: string): Promise<AppearanceUpdateResult> {
    if (this.context === null || this.store === null) {
      throw new Error('个人外观存储尚未初始化');
    }
    // 每次使用新文件名，避免 ArkUI 继续复用同路径的旧图片解码缓存。
    const fileName: string = `interface_background_${Date.now()}.jpg`;
    const targetPath: string = `${this.context.filesDir}/${fileName}`;
    await fileIo.copyFile(sourceUri, targetPath);
    this.coverPath = targetPath;
    await this.store.put(KEY_COVER_PATH, targetPath);
    await this.store.flush();
    this.publish();
    return { uri: CacheFileUri.fromAbsolutePath(targetPath), synced: false };
  }

  async updateAvatarUri(sourceUri: string): Promise<void> {
    await this.updateImageUri(sourceUri, true);
  }

  async updateCoverUri(sourceUri: string): Promise<void> {
    await this.updateImageUri(sourceUri, false);
  }

  async setRandomApiUrl(url: string): Promise<void> {
    if (this.store === null) {
      throw new Error('个人外观存储尚未初始化');
    }
    this.randomImageApi = url.length > 0 ? this.normalizeBuiltInApiUri(url, true) : DEFAULT_RANDOM_IMAGE_API;
    await this.store.put(KEY_RANDOM_IMAGE_API, this.randomImageApi);
    await this.store.flush();
    this.publish();
  }

  async setBackgroundEffects(blurValue: number, maskValue: number): Promise<void> {
    if (this.store === null) {
      throw new Error('个人外观存储尚未初始化');
    }
    this.backgroundBlurValue = Math.max(0, Math.min(40, blurValue));
    this.backgroundMaskValue = Math.max(0, Math.min(0.78, maskValue));
    await this.store.put(KEY_BACKGROUND_BLUR, this.backgroundBlurValue);
    await this.store.put(KEY_BACKGROUND_MASK, this.backgroundMaskValue);
    await this.store.flush();
    this.publish();
  }

  async clearPersonalData(): Promise<void> {
    if (this.store === null) {
      throw new Error('个人外观存储尚未初始化');
    }
    this.removeOwnedImage(this.avatarPath);
    this.removeOwnedImage(this.coverPath);
    this.avatarPath = '';
    this.coverPath = '';
    this.randomImageApi = DEFAULT_RANDOM_IMAGE_API;
    this.backgroundBlurValue = 0;
    this.backgroundMaskValue = 0.32;
    await this.store.delete(KEY_AVATAR_PATH);
    await this.store.delete(KEY_COVER_PATH);
    await this.store.delete(KEY_RANDOM_IMAGE_API);
    await this.store.delete(KEY_BACKGROUND_BLUR);
    await this.store.delete(KEY_BACKGROUND_MASK);
    await this.store.flush();
    this.publish();
  }

  randomAvatarUrl(): string {
    return this.withCacheBuster(this.randomApiUrl());
  }

  randomBackgroundUrl(): string {
    return this.withCacheBuster(DEFAULT_BACKGROUND_IMAGE_API);
  }

  randomAvatarUrlFromSource(useForeignSource: boolean): string {
    const baseUrl: string = useForeignSource ? FOREIGN_IMAGE_API_BASE : DOMESTIC_IMAGE_API_BASE;
    return this.withCacheBuster(baseUrl);
  }

  randomBackgroundUrlForDevice(widthVp: number, heightVp: number, useForeignSource: boolean): string {
    const baseUrl: string = useForeignSource ? FOREIGN_IMAGE_API_BASE : DOMESTIC_IMAGE_API_BASE;
    const sort: string = this.resolveBackgroundSort(widthVp, heightVp);
    return this.withCacheBuster(`${baseUrl}?sort=${sort}`);
  }

  randomBackgroundDeviceDescription(widthVp: number, heightVp: number): string {
    return `sort=${this.resolveBackgroundSort(widthVp, heightVp)}`;
  }

  private async updateImage(sourceUri: string, avatar: boolean): Promise<AppearanceUpdateResult> {
    if (this.context === null || this.store === null) {
      throw new Error('个人外观存储尚未初始化');
    }
    const fileName: string = avatar ?
      `profile_avatar_${Date.now()}.jpg` : `profile_cover_${Date.now()}.jpg`;
    const targetPath: string = `${this.context.filesDir}/${fileName}`;
    await fileIo.copyFile(sourceUri, targetPath);
    if (avatar) {
      this.avatarPath = targetPath;
      await this.store.put(KEY_AVATAR_PATH, targetPath);
    } else {
      this.coverPath = targetPath;
      await this.store.put(KEY_COVER_PATH, targetPath);
    }
    await this.store.flush();

    let synced: boolean = false;
    if (this.provider !== null) {
      try {
        const data: ArrayBuffer = this.readBuffer(targetPath);
        if (avatar) {
          await this.provider.updateProfileAvatar(fileName, 'image/jpeg', data);
        } else {
          await this.provider.updateProfileCover(fileName, 'image/jpeg', data);
        }
        synced = true;
      } catch (err) {
        Logger.warn('ProfileAppearanceStore', `API image sync failed: ${(err as Error).message}`);
      }
    }
    this.publish();
    return { uri: CacheFileUri.fromAbsolutePath(targetPath), synced };
  }

  private async updateImageUri(sourceUri: string, avatar: boolean): Promise<void> {
    if (this.store === null) {
      throw new Error('个人外观存储尚未初始化');
    }
    const refreshedUri: string = this.refreshRemoteUri(this.normalizeBuiltInApiUri(sourceUri, avatar));
    if (avatar) {
      this.avatarPath = refreshedUri;
      await this.store.put(KEY_AVATAR_PATH, refreshedUri);
    } else {
      this.coverPath = refreshedUri;
      await this.store.put(KEY_COVER_PATH, refreshedUri);
    }
    await this.store.flush();
    this.publish();
  }

  private resolveImageUri(source: string): string {
    if (source.length === 0) {
      return '';
    }
    if (source.startsWith('http://') || source.startsWith('https://') || source.startsWith('file://')) {
      return source;
    }
    return CacheFileUri.fromAbsolutePath(source);
  }

  private withCacheBuster(url: string): string {
    const separator: string = url.indexOf('?') >= 0 ? '&' : '?';
    return `${url}${separator}_ht=${Date.now()}`;
  }

  private refreshRemoteUri(sourceUri: string): string {
    if (sourceUri.startsWith('http://') || sourceUri.startsWith('https://')) {
      return this.withCacheBuster(sourceUri);
    }
    return sourceUri;
  }

  private normalizeBuiltInApiUri(sourceUri: string, avatar: boolean): string {
    if (!sourceUri.startsWith(DOMESTIC_IMAGE_API_BASE) && !sourceUri.startsWith(FOREIGN_IMAGE_API_BASE)) {
      return sourceUri;
    }
    if (avatar) {
      return sourceUri
        .replace('?sort=all&size=square&', '?')
        .replace('?sort=all&size=square', '')
        .replace('?size=square&', '?')
        .replace('?size=square', '')
        .replace('&size=square', '');
    }
    return sourceUri
      .replace('&size=mw690', '')
      .replace('&size=mw1024', '')
      .replace('&size=mw2048', '');
  }

  private resolveBackgroundSort(widthVp: number, heightVp: number): string {
    if (widthVp >= heightVp || widthVp >= 700) {
      return 'pc';
    }
    return 'mp';
  }

  private readBuffer(path: string): ArrayBuffer {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      const size: number = fileIo.statSync(path).size;
      const data: ArrayBuffer = new ArrayBuffer(size);
      fileIo.readSync(file.fd, data);
      return data;
    } finally {
      fileIo.closeSync(file);
    }
  }

  private removeOwnedImage(path: string): void {
    if (this.context === null || path.length === 0 || path.startsWith('http://') || path.startsWith('https://') ||
      path.startsWith('file://')) {
      return;
    }
    const ownedPrefix: string = `${this.context.filesDir}/`;
    if (path.startsWith(ownedPrefix)) {
      CacheFileUtil.removeIfExists(path);
    }
  }

  private publish(): void {
    const revision: number = AppStorage.get<number>('profileAppearanceRevision') ?? 0;
    AppStorage.setOrCreate<number>('profileAppearanceRevision', revision + 1);
  }
}
