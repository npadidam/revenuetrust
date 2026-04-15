import { LightningElement, api } from "lwc";

export default class RevtConfirmationDialog extends LightningElement {
  @api title = "Confirm";
  @api message = "Are you sure?";
  @api confirmLabel = "Confirm";
  @api variant = "save"; // 'save', 'submit', 'freeze'
  @api showPartialFullChoice = false;

  isOpen = false;
  selectedScope = "full";

  get confirmVariant() {
    if (this.variant === "freeze") return "destructive";
    if (this.variant === "submit") return "success";
    return "brand";
  }

  get isFreeze() {
    return this.variant === "freeze";
  }

  get scopeOptions() {
    return [
      { label: "All records in view", value: "full" },
      { label: "Only edited records", value: "partial" }
    ];
  }

  @api
  open() {
    this.isOpen = true;
  }

  @api
  close() {
    this.isOpen = false;
  }

  handleScopeChange(event) {
    this.selectedScope = event.detail.value;
  }

  handleConfirm() {
    this.isOpen = false;
    this.dispatchEvent(
      new CustomEvent("confirm", {
        detail: {
          scope: this.selectedScope,
          variant: this.variant
        }
      })
    );
  }

  handleCancel() {
    this.isOpen = false;
    this.dispatchEvent(new CustomEvent("cancel"));
  }
}
