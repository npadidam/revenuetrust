import { LightningElement, api } from "lwc";

/**
 * SVG-based sparkline showing forecast trend within a period.
 * Consumes an array of { date, value, type } data points.
 */
export default class RevtTrendSparkline extends LightningElement {
  @api trendData = [];
  @api width = 100;
  @api height = 24;
  @api color = "#1589EE";

  get hasData() {
    return this.trendData && this.trendData.length >= 2;
  }

  get svgViewBox() {
    return `0 0 ${this.width} ${this.height}`;
  }

  get polylinePoints() {
    const data = this.trendData || [];
    if (data.length < 2) return "";
    const values = data.map((d) => d.value || 0);
    const minVal = Math.min(...values);
    const maxVal = Math.max(...values);
    const range = maxVal - minVal || 1;
    const padding = 2;
    const w = this.width - padding * 2;
    const h = this.height - padding * 2;

    return data
      .map((d, i) => {
        const x = padding + (i / (data.length - 1)) * w;
        const y = padding + h - ((d.value - minVal) / range) * h;
        return `${x},${y}`;
      })
      .join(" ");
  }

  get trendLabel() {
    const data = this.trendData || [];
    if (data.length < 2) return "";
    const first = data[0].value || 0;
    const last = data[data.length - 1].value || 0;
    if (first === 0) return "";
    const pct = Math.round(((last - first) / first) * 100);
    const sign = pct >= 0 ? "+" : "";
    return `${sign}${pct}%`;
  }

  get trendLabelClass() {
    const data = this.trendData || [];
    if (data.length < 2) return "";
    const first = data[0].value || 0;
    const last = data[data.length - 1].value || 0;
    return last >= first ? "trend-up" : "trend-down";
  }
}
