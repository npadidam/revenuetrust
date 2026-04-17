import { LightningElement, api, track } from "lwc";

export default class RevtMultiSelect extends LightningElement {
  @api label = "";
  @api placeholder = "Select...";
  @api singleSelect = false;
  @api fieldLevelHelp = "";

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

  /** Convenience: for single-select mode, accept/return a scalar "value" prop. */
  @api
  get value() {
    return this._selectedValues.length > 0 ? this._selectedValues[0] : null;
  }
  set value(val) {
    this._selectedValues = val ? [val] : [];
  }

  get computedPlaceholder() {
    if (this.singleSelect && this._selectedValues.length === 1) {
      const opt = this._options.find(
        (o) => o.value === this._selectedValues[0]
      );
      return opt ? opt.label : this._selectedValues[0];
    }
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
    // In single-select mode, don't show pills — the value shows in the input
    if (this.singleSelect) return false;
    return this._selectedValues.length > 0;
  }

  get showBulkActions() {
    return !this.singleSelect;
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

  get showHelp() {
    return !!this.fieldLevelHelp;
  }

  openDropdown() {
    this.isDropdownOpen = true;
  }

  handleFocusOut(event) {
    const relatedTarget = event.relatedTarget;
    if (relatedTarget && this.template.contains(relatedTarget)) {
      return;
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      this.isDropdownOpen = false;
    }, 150);
  }

  handleSearchInput(event) {
    this.searchTerm = event.target.value;
    if (!this.isDropdownOpen) {
      this.isDropdownOpen = true;
    }
  }

  handleOptionClick(event) {
    const clickedValue = event.currentTarget.dataset.value;

    if (this.singleSelect) {
      // Single-select: replace current selection, close dropdown, clear search
      this._selectedValues = [clickedValue];
      this.searchTerm = "";
      this.isDropdownOpen = false;
      this.fireChange();
      return;
    }

    // Multi-select: toggle
    const idx = this._selectedValues.indexOf(clickedValue);
    if (idx >= 0) {
      this._selectedValues = this._selectedValues.filter(
        (v) => v !== clickedValue
      );
    } else {
      this._selectedValues = [...this._selectedValues, clickedValue];
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
    const pillValue = event.target.name;
    this._selectedValues = this._selectedValues.filter((v) => v !== pillValue);
    this.fireChange();
  }

  fireChange() {
    if (this.singleSelect) {
      this.dispatchEvent(
        new CustomEvent("change", {
          detail: {
            value: this._selectedValues[0] || null,
            selectedValues: [...this._selectedValues]
          }
        })
      );
    } else {
      this.dispatchEvent(
        new CustomEvent("change", {
          detail: { selectedValues: [...this._selectedValues] }
        })
      );
    }
  }
}
