@Concurrent
export function parseJsonTextConcurrent(text: string): string {
  const parsed: Object = JSON.parse(text) as Object;
  return JSON.stringify(parsed);
}
