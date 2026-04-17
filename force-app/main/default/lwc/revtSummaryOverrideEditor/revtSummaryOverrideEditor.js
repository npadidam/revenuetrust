import { LightningElement, api } from "lwc";

/**
 * Inline popover for overriding a forecast category summary.
 * Manager enters override amount + notes.
 */
export default class RevtSummaryOverrideEditor extends LightningElement {
  @api summaryId;
  @api categoryName;
  @api computedValue = 0;
  @api currentOverride = null;
  @api currentNotes = "";

  _overrideValue = null;
  _notes = "";
  isOpen = false;

  connectedCallback() {
    this._overrideValue = this.currentOverride;
    this._notes = this.currentNotes || "";
  }

  @api open() {
    this._overrideValue =
      this.currentOverride != null ? this.currentOverride : this.computedValue;
    this._notes = this.currentNotes || "";
    this.isOpen = true;
  }

  @api close() {
    this.isOpen = false;
  }

  get headerLabel() {
    return "Override: " + (this.categoryName || "Category");
  }

  get formattedComputed() {
    const v = Number(this.computedValue) || 0;
    return "$" + v.toLocaleString();
  }

  get hasDelta() {
    return (
      this._overrideValue != null && this._overrideValue !== this.computedValue
    );
  }

  get deltaAmount() {
    const delta = (this._overrideValue || 0) - (this.computedValue || 0);
    const sign = delta >= 0 ? "+" : "";
    return sign + "$" + Math.abs(delta).toLocaleString();
  }

  handleOverrideChange(event) {
    this._overrideValue = event.detail.value
      ? Number(event.detail.value)
      : null;
  }

  handleNotesChange(event) {
    this._notes = event.detail.value;
  }

  handleSave() {
    this.dispatchEvent(
      new CustomEvent("save", {
        detail: {
          summaryId: this.summaryId,
          overrideValue: this._overrideValue,
          notes: this._notes
        }
      })
    );
    this.isOpen = false;
  }

  handleClear() {
    this.dispatchEvent(
      new CustomEvent("clear", {
        detail: { summaryId: this.summaryId }
      })
    );
    this.isOpen = false;
  }

  handleCancel() {
    this.isOpen = false;
  }
}
