interface PromptActionLike {
  showToast(options: ToastOptions): void;
}

interface UiContextLike {
  getPromptAction(): PromptActionLike;
}

interface UiHostLike {
  getUIContext(): UiContextLike;
}

interface ToastOptions {
  message: string;
  duration: number;
}

export class ToastUtil {
  static show(host: UiHostLike, message: string, duration: number = 1600): void {
    try {
      const options: ToastOptions = {
        message,
        duration
      };
      host.getUIContext().getPromptAction().showToast(options);
    } catch (_err) {
    }
  }
}
