@Concurrent
export function parseSubsonicEnvelopeConcurrent(text: string): string {
  const subsonicWrapperKey: string = 'subsonic-response';
  const subsonicErrPrefix: string = 'SUBSONIC_ERR:';
  const raw: Object = JSON.parse(text) as Object;
  const entries: [string, Object][] = Object.entries(raw);
  let env: Object | undefined = undefined;
  for (let i: number = 0; i < entries.length; i++) {
    if (entries[i][0] === subsonicWrapperKey) {
      env = entries[i][1];
    }
  }
  if (env === undefined) {
    throw new Error(`${subsonicErrPrefix}-1:Missing subsonic-response wrapper`);
  }
  const envRecord: Record<string, Object> = env as Record<string, Object>;
  const status: Object | undefined = envRecord['status'];
  if (status === 'failed') {
    let errCode: number = -1;
    let errMsg: string = 'Unknown error';
    const errorObj: Object | undefined = envRecord['error'];
    if (errorObj !== undefined) {
      const errorRecord: Record<string, Object> = errorObj as Record<string, Object>;
      const codeVal: Object | undefined = errorRecord['code'];
      const msgVal: Object | undefined = errorRecord['message'];
      if (typeof codeVal === 'number') {
        errCode = codeVal;
      }
      if (typeof msgVal === 'string') {
        errMsg = msgVal;
      }
    }
    throw new Error(`${subsonicErrPrefix}${errCode}:${errMsg}`);
  }
  return JSON.stringify(env);
}
