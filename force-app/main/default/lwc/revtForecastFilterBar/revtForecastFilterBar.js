import { LightningElement, api, track } from "lwc";
import {
  sessionStorageGet,
  sessionStorageSet,
  sessionStorageRemove
} from "c/revtForecastUtils";

export default class RevtForecastFilterBar extends LightningElement {
  @api config;
  @api context;
  @api stageValues = []; // distinct stage values from records
  @api periodId;
  @api scopeId;
  @api participantId;
  @api records = []; // all records for auto-suggest

  @track searchText = "";
  @track selectedCategories = [];
  @track selectedStages = [];
  @track selectedHealthBands = [];
  @track overriddenOnly = false;
  @track divergentOnly = false;
  @track pendingApprovalOnly = false;
  @track suggestions = [];

  _initialized = false;
  _suggestionsVisible = false;

  get storageKey() {
    return `revt_forecast_filters_${this.periodId}_${this.scopeId}_${this.participantId}`;
  }

  get isBudgetMode() {
    return this.context && this.context.isBudgetMode;
  }

  get categoryOptions() {
    if (!this.config || !this.config.categories) return [];
    return this.config.categories
      .filter((c) => c.isActive)
      .map((c) => ({ label: c.label || c.name, value: c.apiName || c.name }));
  }

  get stageOptions() {
    return (this.stageValues || []).map((s) => ({ label: s, value: s }));
  }

  get healthOptions() {
    return [
      { label: "Green (Healthy)", value: "Green" },
      { label: "Yellow (At Risk)", value: "Yellow" },
      { label: "Red (Critical)", value: "Red" }
    ];
  }

  _filterTimeout;
  _searchTimeout;

  connectedCallback() {
    this.restoreFilters();
    this._initialized = true;
  }

  @api
  clearAndReset() {
    this.handleClearAll();
  }

  restoreFilters() {
    const saved = sessionStorageGet(this.storageKey);
    if (saved) {
      this.searchText = saved.searchText || "";
      this.selectedCategories = saved.selectedCategories || [];
      this.selectedStages = saved.selectedStages || [];
      this.selectedHealthBands = saved.selectedHealthBands || [];
      this.overriddenOnly = saved.overriddenOnly || false;
      this.divergentOnly = saved.divergentOnly || false;
      this.pendingApprovalOnly = saved.pendingApprovalOnly || false;
    }
  }

  persistFilters() {
    sessionStorageSet(this.storageKey, {
      searchText: this.searchText,
      selectedCategories: this.selectedCategories,
      selectedStages: this.selectedStages,
      selectedHealthBands: this.selectedHealthBands,
      overriddenOnly: this.overriddenOnly,
      divergentOnly: this.divergentOnly,
      pendingApprovalOnly: this.pendingApprovalOnly
    });
  }

  // ── Handlers ──

  get showSuggestions() {
    return this._suggestionsVisible && this.suggestions.length > 0;
  }

  handleSearchChange(event) {
    this.searchText = event.detail.value || "";
    // Build auto-suggest from records
    if (this.searchText.length >= 2 && this.records) {
      const search = this.searchText.toLowerCase();
      this.suggestions = this.records
        .filter(
          (r) =>
            (r.recordName && r.recordName.toLowerCase().includes(search)) ||
            (r.ownerName && r.ownerName.toLowerCase().includes(search))
        )
        .slice(0, 8)
        .map((r) => ({
          id: r.recordId,
          name: r.recordName,
          owner: r.ownerName || ""
        }));
      this._suggestionsVisible = true;
    } else {
      this.suggestions = [];
      this._suggestionsVisible = false;
    }

    // If search was cleared (X button or empty), dismiss suggestions and fire immediately
    if (!this.searchText) {
      this._suggestionsVisible = false;
      this.suggestions = [];
      this.fireFilterChange();
    } else {
      this._debouncedSearch();
    }
  }

  handleSearchKeydown(event) {
    if (event.key === "Enter" || event.key === "Escape") {
      this._suggestionsVisible = false;
      this.suggestions = [];
      clearTimeout(this._searchTimeout);
      this.fireFilterChange();
    }
  }

  handleSearchBlur() {
    // Small delay to allow suggestion click to register before hiding
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      this._suggestionsVisible = false;
      this.suggestions = [];
    }, 200);
  }

  handleSuggestionClick(event) {
    const id = event.currentTarget.dataset.id;
    const rec = this.suggestions.find((s) => s.id === id);
    if (rec) {
      this.searchText = rec.name;
    }
    this._suggestionsVisible = false;
    this.suggestions = [];
    this.fireFilterChange();
  }

  handleCategoryChange(event) {
    this.selectedCategories = event.detail.selectedValues;
    this._debouncedFilter();
  }

  handleStageChange(event) {
    this.selectedStages = event.detail.selectedValues;
    this._debouncedFilter();
  }

  handleHealthChange(event) {
    this.selectedHealthBands = event.detail.selectedValues;
    this._debouncedFilter();
  }

  handleOverriddenChange(event) {
    this.overriddenOnly = event.target.checked;
    this._debouncedFilter();
  }

  handleDivergentChange(event) {
    this.divergentOnly = event.target.checked;
    this._debouncedFilter();
  }

  handlePendingChange(event) {
    this.pendingApprovalOnly = event.target.checked;
    this._debouncedFilter();
  }

  // Inline debounce — avoids Locker Service issues with external debounce + setTimeout
  _debouncedSearch() {
    clearTimeout(this._searchTimeout);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._searchTimeout = setTimeout(() => {
      this._suggestionsVisible = false;
      this.suggestions = [];
      this.fireFilterChange();
    }, 300);
  }

  _debouncedFilter() {
    clearTimeout(this._filterTimeout);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._filterTimeout = setTimeout(() => {
      this.fireFilterChange();
    }, 250);
  }

  handleClearAll() {
    this.searchText = "";
    this.selectedCategories = [];
    this.selectedStages = [];
    this.selectedHealthBands = [];
    this.overriddenOnly = false;
    this.divergentOnly = false;
    this.pendingApprovalOnly = false;
    sessionStorageRemove(this.storageKey);
    this.fireFilterChange();
  }

  fireFilterChange() {
    console.log(
      "FilterBar: fireFilterChange called, searchText =",
      this.searchText
    );
    this.persistFilters();
    this.dispatchEvent(
      new CustomEvent("filterchange", {
        detail: {
          searchText: this.searchText || null,
          categoryFilter:
            this.selectedCategories.length > 0 ? this.selectedCategories : null,
          stageFilter:
            this.selectedStages.length > 0 ? this.selectedStages : null,
          healthBandFilter:
            this.selectedHealthBands.length > 0
              ? this.selectedHealthBands
              : null,
          overriddenOnly: this.overriddenOnly,
          divergentOnly: this.divergentOnly,
          pendingApprovalOnly: this.pendingApprovalOnly
        }
      })
    );
  }
}
