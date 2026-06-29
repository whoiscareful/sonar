import { common, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { Logger } from '../common/Logger';

const NOTIFICATION_ID: number = 1001;
const SLOT_TYPE: notificationManager.SlotType = notificationManager.SlotType.SOCIAL_COMMUNICATION;
const ABILITY_NAME: string = 'SonarAbility';

export class BackgroundPlayback {
  private static context: common.UIAbilityContext | null = null;
  private static started: boolean = false;
  private static slotInitialized: boolean = false;
  private static agent: Object | null = null;

  static setContext(context: common.UIAbilityContext): void {
    BackgroundPlayback.context = context;
  }

  static async start(songTitle: string, songArtist: string, isPlaying: boolean): Promise<void> {
    if (BackgroundPlayback.context === null) {
      Logger.warn('BackgroundPlayback', 'start skipped: missing context');
      return;
    }
    await BackgroundPlayback.ensureNotificationSlot();
    await BackgroundPlayback.ensureBackgroundTask();
    await BackgroundPlayback.publishNotification(songTitle, songArtist, isPlaying);
  }

  static async update(songTitle: string, songArtist: string, isPlaying: boolean): Promise<void> {
    if (!BackgroundPlayback.started || BackgroundPlayback.context === null) {
      return;
    }
    await BackgroundPlayback.publishNotification(songTitle, songArtist, isPlaying);
  }

  static async stop(): Promise<void> {
    if (BackgroundPlayback.context === null) {
      return;
    }
    if (BackgroundPlayback.started) {
      try {
        await backgroundTaskManager.stopBackgroundRunning(BackgroundPlayback.context);
      } catch (err) {
        Logger.warn('BackgroundPlayback', `stopBackgroundRunning failed: ${(err as Error).message}`);
      }
      BackgroundPlayback.started = false;
    }
    try {
      await notificationManager.cancel(NOTIFICATION_ID);
    } catch (err) {
      Logger.warn('BackgroundPlayback', `cancel notification failed: ${(err as Error).message}`);
    }
  }

  static async release(): Promise<void> {
    await BackgroundPlayback.stop();
    BackgroundPlayback.agent = null;
  }

  private static async ensureBackgroundTask(): Promise<void> {
    if (BackgroundPlayback.context === null || BackgroundPlayback.started) {
      return;
    }
    try {
      const agent = await BackgroundPlayback.ensureWantAgent();
      if (agent === null) {
        Logger.warn('BackgroundPlayback', 'startBackgroundRunning skipped: wantAgent unavailable');
        return;
      }
      await backgroundTaskManager.startBackgroundRunning(
        BackgroundPlayback.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        agent
      );
      BackgroundPlayback.started = true;
    } catch (err) {
      const message: string = (err as Error).message;
      if (message.indexOf('9800005') >= 0) {
        BackgroundPlayback.started = true;
        return;
      }
      Logger.error('BackgroundPlayback', `startBackgroundRunning failed: ${message}`);
    }
  }

  private static async ensureNotificationSlot(): Promise<void> {
    if (BackgroundPlayback.slotInitialized) {
      return;
    }
    try {
      await notificationManager.addSlot(SLOT_TYPE);
      BackgroundPlayback.slotInitialized = true;
    } catch (err) {
      Logger.warn('BackgroundPlayback', `addSlot failed: ${(err as Error).message}`);
    }
  }

  private static async ensureWantAgent(): Promise<Object | null> {
    if (BackgroundPlayback.agent !== null) {
      return BackgroundPlayback.agent;
    }
    if (BackgroundPlayback.context === null) {
      return null;
    }
    const bundleName: string = BackgroundPlayback.context.abilityInfo.bundleName;
    const info: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName,
        abilityName: ABILITY_NAME
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      BackgroundPlayback.agent = await wantAgent.getWantAgent(info);
    } catch (err) {
      Logger.warn('BackgroundPlayback', `getWantAgent failed: ${(err as Error).message}`);
      return null;
    }
    return BackgroundPlayback.agent;
  }

  private static async publishNotification(songTitle: string, songArtist: string, isPlaying: boolean): Promise<void> {
    const title: string = songTitle.length > 0 ? songTitle : 'Sonar';
    const text: string = songArtist.length > 0 ? songArtist : '未知歌手';
    const hint: string = isPlaying ? '正在播放' : '已暂停播放';
    const request: notificationManager.NotificationRequest = {
      id: NOTIFICATION_ID,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title,
          text,
          additionalText: hint
        }
      },
      deliveryTime: Date.now(),
      showDeliveryTime: true,
      tapDismissed: false
    };
    try {
      await notificationManager.publish(request);
    } catch (err) {
      Logger.warn('BackgroundPlayback', `publish notification failed: ${(err as Error).message}`);
    }
  }
}
