import { LightningElement, api } from "lwc";
import { formatCurrency, formatPercent } from "c/revtForecastUtils";

export default class RevtInlineEstimator extends LightningElement {
  @api payoutEstimate;
  @api incentiveRate;
  @api thresholdProximity;
  @api tierImpact;
  @api currencyCode = "USD";

  get hasData() {
    return this.payoutEstimate != null || this.incentiveRate != null;
  }

  get formattedPayout() {
    return formatCurrency(this.payoutEstimate, this.currencyCode);
  }

  get formattedRate() {
    return this.incentiveRate != null ? formatPercent(this.incentiveRate) : "—";
  }

  get isTierCrossing() {
    return this.tierImpact && this.tierImpact.startsWith("Crosses");
  }

  get containerClass() {
    let cls = "inline-estimator";
    if (this.isTierCrossing) {
      cls += " has-crossing";
    }
    return cls;
  }

  get tooltipText() {
    const parts = [];
    if (this.payoutEstimate != null) {
      parts.push("Estimated payout: " + this.formattedPayout);
    }
    if (this.incentiveRate != null) {
      parts.push("Current rate: " + this.formattedRate);
    }
    if (this.thresholdProximity != null) {
      parts.push(
        "Distance to next tier: " +
          formatCurrency(this.thresholdProximity, this.currencyCode)
      );
    }
    if (this.tierImpact) {
      parts.push(this.tierImpact);
    }
    return parts.join(" | ");
  }
}
