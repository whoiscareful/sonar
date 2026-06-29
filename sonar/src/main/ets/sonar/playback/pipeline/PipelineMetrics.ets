/** 管线观测计数 */
export class PipelineMetricsSnapshot {
  trackStarts: number = 0;
  migrates: number = 0;
  seeks: number = 0;
}

export class PipelineMetrics {
  private static trackStarts: number = 0;
  private static migrates: number = 0;
  private static seeks: number = 0;

  static recordTrackStart(): void {
    PipelineMetrics.trackStarts++;
  }

  static recordMigrate(): void {
    PipelineMetrics.migrates++;
  }

  static recordSeek(): void {
    PipelineMetrics.seeks++;
  }

  static snapshot(): PipelineMetricsSnapshot {
    const result: PipelineMetricsSnapshot = new PipelineMetricsSnapshot();
    result.trackStarts = PipelineMetrics.trackStarts;
    result.migrates = PipelineMetrics.migrates;
    result.seeks = PipelineMetrics.seeks;
    return result;
  }
}
