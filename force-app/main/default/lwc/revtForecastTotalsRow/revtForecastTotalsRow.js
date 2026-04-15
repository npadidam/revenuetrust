import { LightningElement, api } from "lwc";

export default class RevtForecastTotalsRow extends LightningElement {
  @api summary; // ForecastSummaryDTO
  @api config; // ForecastConfigDTO
  @api records; // Array of ForecastRecordDTO for client-side totals
  @api showHealthBadge;
  @api showInlineEstimator;

  get recordCount() {
    return this.records ? this.records.length : 0;
  }

  get metricTotals() {
    if (!this.config || !this.config.metrics || !this.records) return [];
    return this.config.metrics
      .filter((m) => m.isEditable)
      .map((m, idx) => {
        const key = "metric_" + (idx + 1);
        let total = 0;
        for (const rec of this.records) {
          const val = rec.metricValues ? rec.metricValues[key] : null;
          if (val != null) total += val;
        }
        return { key, label: m.label, value: total };
      });
  }

  get categoryTotalsList() {
    if (!this.summary || !this.summary.categoryTotals || !this.config)
      return [];
    return this.config.categories
      .filter((c) => c.isActive)
      .map((c) => {
        const name = c.apiName || c.name;
        return {
          name: c.label || c.name,
          color: c.color || "#706E6B",
          total: this.summary.categoryTotals[name] || 0,
          count: this.summary.categoryCounts
            ? this.summary.categoryCounts[name] || 0
            : 0
        };
      })
      .filter((ct) => ct.count > 0);
  }
}
