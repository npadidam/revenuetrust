import { LightningElement, api, track } from "lwc";

export default class RevtMultiSelect extends LightningElement {
  @api label = "";
  @api placeholder = "Select...";

  @track _options = [];
  @track _selectedValues = [];
  @track searchTerm = "";

  isDropdownOpen = false;

  @api
  get options() {
    return this._options;
  }
  set options(value) {
    this._options = value ? [...value] : [];
  }

  @api
  get selectedValues() {
    return this._selectedValues;
  }
  set selectedValues(value) {
    this._selectedValues = value ? [...value] : [];
  }

  get computedPlaceholder() {
    if (this._selectedValues.length > 0) {
      return this._selectedValues.length + " selected";
    }
    return this.placeholder;
  }

  get filteredOptions() {
    const search = (this.searchTerm || "").toLowerCase();
    return this._options
      .filter((opt) => !search || opt.label.toLowerCase().includes(search))
      .map((opt) => ({
        ...opt,
        selected: this._selectedValues.includes(opt.value),
        itemClass:
          "slds-media slds-listbox__option slds-listbox__option_plain slds-media_small" +
          (this._selectedValues.includes(opt.value) ? " slds-is-selected" : "")
      }));
  }

  get noResults() {
    return this.filteredOptions.length === 0;
  }

  get hasSelections() {
    return this._selectedValues.length > 0;
  }

  get selectedPills() {
    const optMap = new Map(this._options.map((o) => [o.value, o.label]));
    return this._selectedValues.map((v) => ({
      value: v,
      label: optMap.get(v) || v
    }));
  }

  get comboboxClass() {
    return (
      "slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click" +
      (this.isDropdownOpen ? " slds-is-open" : "")
    );
  }

  openDropdown() {
    this.isDropdownOpen = true;
  }

  handleFocusOut(event) {
    // Close dropdown when focus moves outside the component (Locker-safe click-outside)
    const relatedTarget = event.relatedTarget;
    if (relatedTarget && this.template.contains(relatedTarget)) {
      return; // Focus moved within the component
    }
    // Small delay to allow click handlers to fire first
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      this.isDropdownOpen = false;
    }, 150);
  }

  handleSearchInput(event) {
    this.searchTerm = event.target.value;
  }

  handleOptionClick(event) {
    const value = event.currentTarget.dataset.value;
    const idx = this._selectedValues.indexOf(value);
    if (idx >= 0) {
      this._selectedValues = this._selectedValues.filter((v) => v !== value);
    } else {
      this._selectedValues = [...this._selectedValues, value];
    }
    this.fireChange();
  }

  handleSelectAll() {
    this._selectedValues = this._options.map((o) => o.value);
    this.fireChange();
  }

  handleClearAll() {
    this._selectedValues = [];
    this.fireChange();
  }

  handlePillRemove(event) {
    const value = event.target.name;
    this._selectedValues = this._selectedValues.filter((v) => v !== value);
    this.fireChange();
  }

  fireChange() {
    this.dispatchEvent(
      new CustomEvent("change", {
        detail: { selectedValues: [...this._selectedValues] }
      })
    );
  }
}
