import { LightningElement, api } from "lwc";

export default class RevtCategoryPill extends LightningElement {
  @api label;
  @api color; // hex color string e.g. '#04844B'
  @api isTerminal = false;

  get pillStyle() {
    const bgColor = this.color || "#706E6B";
    return `background-color: ${bgColor}; color: #ffffff;`;
  }

  get pillClass() {
    let cls = "category-pill";
    if (this.isTerminal) {
      cls += " terminal";
    }
    return cls;
  }
}
