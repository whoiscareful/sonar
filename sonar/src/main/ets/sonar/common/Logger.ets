import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x534E; // 'SN'
const PREFIX = 'Sonar';

export class Logger {
  static debug(tag: string, msg: string): void {
    hilog.debug(DOMAIN, `${PREFIX}/${tag}`, msg);
  }

  static info(tag: string, msg: string): void {
    hilog.info(DOMAIN, `${PREFIX}/${tag}`, msg);
  }

  static warn(tag: string, msg: string): void {
    hilog.warn(DOMAIN, `${PREFIX}/${tag}`, msg);
  }

  static error(tag: string, msg: string): void {
    hilog.error(DOMAIN, `${PREFIX}/${tag}`, msg);
  }
}
