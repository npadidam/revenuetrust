import { LightningElement, api } from "lwc";
import { formatCurrency, formatPercent } from "c/revtForecastUtils";

export default class RevtForecastSummaryPanel extends LightningElement {
  @api summary; // ForecastSummaryDTO
  @api context; // ForecastParticipantContextDTO
  @api config; // ForecastConfigDTO

  get isBudgetMode() {
    return this.context && this.context.isBudgetMode;
  }

  get panelTitle() {
    return this.isBudgetMode ? "Budget" : "Forecast";
  }

  get showAttainment() {
    return (
      !this.isBudgetMode &&
      this.summary &&
      (this.summary.target > 0 || this.summary.achieved > 0)
    );
  }

  get categoryColumnClass() {
    return this.showAttainment
      ? "slds-col slds-size_1-of-2"
      : "slds-col slds-size_1-of-1";
  }

  // ── Attainment ring ──

  get attainmentPct() {
    return this.summary ? this.summary.attainmentPct || 0 : 0;
  }

  get attainmentPctDisplay() {
    return Math.round(this.attainmentPct) + "%";
  }

  get attainmentLabel() {
    return "Attainment: " + this.attainmentPctDisplay;
  }

  get attainmentBandLabel() {
    const pct = this.attainmentPct;
    if (pct >= 100) return "Above Target";
    if (pct >= 90) return "Near Target";
    if (pct >= 50) return "On Track";
    return "Below Target";
  }

  get ringColor() {
    const pct = this.attainmentPct;
    if (pct >= 100) return "#1589EE";
    if (pct >= 90) return "#04844B";
    if (pct >= 50) return "#F2CF00";
    return "#EA001E";
  }

  get ringDashArray() {
    const circumference = 2 * Math.PI * 50; // r=50
    return String(circumference);
  }

  get ringDashOffset() {
    const circumference = 2 * Math.PI * 50;
    const pct = Math.min(this.attainmentPct, 100) / 100;
    return String(circumference * (1 - pct));
  }

  get formattedTarget() {
    return this.summary ? formatCurrency(this.summary.target) : "$0";
  }

  get formattedAchieved() {
    return this.summary ? formatCurrency(this.summary.achieved) : "$0";
  }

  get formattedRemaining() {
    return this.summary ? formatCurrency(this.summary.remaining) : "$0";
  }

  // ── Category totals ──

  get categoryRows() {
    if (!this.summary || !this.summary.categoryTotals || !this.config)
      return [];
    const categories = this.config.categories || [];
    return categories
      .filter((c) => c.isActive)
      .map((c) => {
        const key = c.apiName || c.name;
        return {
          name: key,
          label: c.label || c.name,
          color: c.color || "#706E6B",
          total: this.summary.categoryTotals[key] || 0,
          count: this.summary.categoryCounts
            ? this.summary.categoryCounts[key] || 0
            : 0
        };
      })
      .filter((cr) => cr.count > 0 || cr.total > 0);
  }

  // ── Coverage ──

  get coverageLabel() {
    return this.isBudgetMode ? "Budget Coverage" : "Coverage Ratio";
  }

  get formattedCoverage() {
    if (!this.summary || this.summary.coverageRatio == null) return "N/A";
    return this.summary.coverageRatio.toFixed(1) + "x";
  }

  get coverageClass() {
    const ratio = this.summary ? this.summary.coverageRatio : 0;
    let cls = "metric-value";
    if (ratio >= 3) cls += " coverage-healthy";
    else if (ratio >= 1.5) cls += " coverage-caution";
    else cls += " coverage-low";
    return cls;
  }

  // ── Tier info ──

  get showTierInfo() {
    return (
      !this.isBudgetMode &&
      this.summary &&
      (this.summary.currentTier || this.summary.currentRate)
    );
  }

  get formattedCurrentRate() {
    return this.summary && this.summary.currentRate != null
      ? formatPercent(this.summary.currentRate)
      : "—";
  }

  get formattedNextTierDistance() {
    return this.summary ? formatCurrency(this.summary.nextTierDistance) : "$0";
  }
}
