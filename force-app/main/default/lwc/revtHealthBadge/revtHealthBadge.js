import { LightningElement, api } from "lwc";
import { HEALTH_BAND_CONFIG, HEALTH_BAND_DEFAULT } from "c/revtForecastUtils";

export default class RevtHealthBadge extends LightningElement {
  @api healthScore;
  @api healthBand;

  get config() {
    if (this.healthBand && HEALTH_BAND_CONFIG[this.healthBand]) {
      return HEALTH_BAND_CONFIG[this.healthBand];
    }
    return HEALTH_BAND_DEFAULT;
  }

  get iconName() {
    return this.config.icon;
  }

  get badgeTitle() {
    const score = this.healthScore != null ? this.healthScore + "/100" : "N/A";
    return `Health: ${score} (${this.config.label})`;
  }

  get badgeClass() {
    return "health-badge band-" + (this.healthBand || "none").toLowerCase();
  }

  get showScore() {
    return this.healthScore != null;
  }
}
