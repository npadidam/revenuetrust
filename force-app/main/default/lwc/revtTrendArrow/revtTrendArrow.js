import { LightningElement, api } from "lwc";

export default class RevtTrendArrow extends LightningElement {
  @api trend; // -1, 0, or +1
  @api label; // optional label text

  get iconName() {
    if (this.trend === 1 || this.trend === "1") return "utility:arrowup";
    if (this.trend === -1 || this.trend === "-1") return "utility:arrowdown";
    return "utility:dash";
  }

  get trendClass() {
    if (this.trend === 1 || this.trend === "1") return "trend-arrow trend-up";
    if (this.trend === -1 || this.trend === "-1")
      return "trend-arrow trend-down";
    return "trend-arrow trend-flat";
  }

  get trendLabel() {
    const prefix = this.label ? this.label + ": " : "";
    if (this.trend === 1 || this.trend === "1")
      return prefix + "Up from previous period";
    if (this.trend === -1 || this.trend === "-1")
      return prefix + "Down from previous period";
    return prefix + "No change";
  }
}
