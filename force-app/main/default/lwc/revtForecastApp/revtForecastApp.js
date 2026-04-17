import { LightningElement, wire, track, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import hasActiveConfig from "@salesforce/apex/ForecastController.hasActiveConfig";
import getForecastConfig from "@salesforce/apex/ForecastController.getForecastConfig";
import getParticipantContext from "@salesforce/apex/ForecastController.getParticipantContext";
import getParticipantContextForUser from "@salesforce/apex/ForecastController.getParticipantContextForUser";
import getForecastRecords from "@salesforce/apex/ForecastController.getForecastRecords";
import saveForecastData from "@salesforce/apex/ForecastController.saveForecastData";
import submitForecastData from "@salesforce/apex/ForecastController.submitForecastData";
import freezeForecastData from "@salesforce/apex/ForecastController.freezeForecastData";
import copyFromPreviousLevel from "@salesforce/apex/ForecastController.copyFromPreviousLevel";
import copyFromLastForecast from "@salesforce/apex/ForecastController.copyFromLastForecast";
import overrideSummaryValue from "@salesforce/apex/ForecastController.overrideSummaryValue";
import clearSummaryOverride from "@salesforce/apex/ForecastController.clearSummaryOverride";
import getParticipantIdForUser from "@salesforce/apex/ForecastController.getParticipantIdForUser";
import getGroupsForActiveConfig from "@salesforce/apex/ForecastController.getGroupsForActiveConfig";
import {
  chunkArray,
  parseErrorPrefix,
  sessionStorageGet,
  sessionStorageSet
} from "c/revtForecastUtils";

const SAVE_CHUNK_SIZE = 50;

// Phase C: Forecast horizon options shown in the toolbar.
const HORIZON_OPTIONS = [
  { label: "Current Period", value: "Current_Period" },
  { label: "Current + Next", value: "Current_Plus_Next" },
  { label: "Current Quarter", value: "Quarter" },
  { label: "Current + Next Quarter", value: "Quarter_Plus_Next" },
  { label: "Fiscal Year", value: "Fiscal_Year" },
  { label: "Custom", value: "Custom" }
];

// sessionStorage key for the user's horizon preference, scoped per participant.
const HORIZON_STORAGE_PREFIX = "revt_horizon_";

export default class RevtForecastApp extends NavigationMixin(LightningElement) {
  @api title = "Forecast";
  @api showInlineEstimator;
  @api showHealthBadge;

  // ── Wizard detection ──
  showWizard = false;
  configChecked = false;

  @wire(hasActiveConfig)
  wiredHasConfig({ data, error }) {
    if (data !== undefined) {
      this.showWizard = !data;
      this.configChecked = true;
    } else if (error) {
      // If check fails, assume config exists and show grid
      this.configChecked = true;
      this.showWizard = false;
    }
  }

  get showForecastGrid() {
    return this.configChecked && !this.showWizard;
  }

  handleWizardComplete() {
    // Wizard finished activation — switch to forecast grid
    this.showWizard = false;
  }

  // ── Config (cacheable wire) ──
  config;
  @wire(getForecastConfig)
  wiredConfig({ data, error }) {
    if (data) {
      this.config = data;
      this.pageSize = data.paginationSize || 40;
      // Phase C: initialize horizon from sessionStorage (if present) or config default
      if (!this.selectedHorizon) {
        const stored = sessionStorageGet(this._horizonStorageKey());
        this.selectedHorizon =
          stored || data.defaultHorizon || "Current_Period";
      }
      if (data.currentPeriod && !this.selectedPeriodId) {
        this.selectedPeriodId = data.currentPeriod.periodId;
        this.loadContext();
      }
    } else if (error) {
      // Only show error if we're supposed to show the grid
      if (!this.showWizard) {
        this.showError("Failed to load forecast configuration.");
      }
    }
  }

  // ── Core state ──
  context;
  @track allRecords = [];
  @track displayRecords = [];
  currentSummary;
  totalCount = 0;
  totalUnfilteredCount = 0;

  // ── Selection state ──
  selectedPeriodId;
  selectedScopeId;
  selectedGroupId; // Phase B
  selectedHorizon; // Phase C
  currentPage = 1;
  pageSize = 40;
  isClientSideFiltering = false;
  isLocalCurrency = false;

  // Phase C: when summary.readOnly==true (multi-period horizon), edits/save/submit/freeze are hidden
  isHorizonReadOnly = false;

  // ── Phase B: Forecast Groups ──
  @track groups = [];

  @wire(getGroupsForActiveConfig)
  wiredGroups({ data, error }) {
    if (data) {
      this.groups = data;
      // Default to "All Groups" (empty string = no group filter)
      if (this.selectedGroupId === undefined || this.selectedGroupId === null) {
        this.selectedGroupId = "";
      }
    } else if (error) {
      this.groups = [];
    }
  }

  get groupOptions() {
    const opts = [{ label: "All Groups", value: "" }];
    for (const g of this.groups || []) {
      opts.push({ label: g.groupName, value: g.groupId });
    }
    return opts;
  }

  get showGroupPicker() {
    return (this.groups || []).length >= 1;
  }

  handleGroupChange(event) {
    this.selectedGroupId = event.detail.value;
    this.currentPage = 1;
    this.loadRecords();
  }

  // ── Phase C: Horizon picker ──

  get horizonOptions() {
    return HORIZON_OPTIONS;
  }

  get showHorizonPicker() {
    // Show whenever config is loaded — single horizon orgs still see the option
    return !!this.config;
  }

  /**
   * sessionStorage key for the user's horizon preference, scoped per participant
   * so different drill-in views (or different participants on the same browser)
   * don't share state.
   */
  _horizonStorageKey() {
    const pid = this.currentParticipantId || "anon";
    return HORIZON_STORAGE_PREFIX + pid;
  }

  handleHorizonChange(event) {
    const newVal = event.detail.value;
    // Dirty-check: if there are unsaved edits, confirm before reloading
    if (this.dirtyOverrides.size > 0) {
      // eslint-disable-next-line no-alert
      const ok = window.confirm(
        "You have unsaved changes. Switching horizons will discard them. Continue?"
      );
      if (!ok) {
        // Revert visually by re-emitting the old value (re-render via reassignment)
        const prev = this.selectedHorizon;
        this.selectedHorizon = null;

        this.selectedHorizon = prev;
        return;
      }
      this.dirtyOverrides.clear();
    }
    this.selectedHorizon = newVal;
    sessionStorageSet(this._horizonStorageKey(), newVal);
    this.currentPage = 1;
    this.loadRecords();
  }

  // ── Phase C: Final / Stretch summary cards ──

  get showFinalCard() {
    return this.currentSummary && this.currentSummary.finalForecast != null;
  }

  get showStretchCard() {
    return this.currentSummary && this.currentSummary.stretchForecast != null;
  }

  get finalCardLabel() {
    return (
      this.currentSummary?.finalLabel ||
      this.config?.finalForecastLabel ||
      "Final Forecast"
    );
  }

  get stretchCardLabel() {
    return (
      this.currentSummary?.stretchLabel ||
      this.config?.stretchForecastLabel ||
      "Stretch Forecast"
    );
  }

  get formattedFinalAmount() {
    return this._formatAmountShort(this.currentSummary?.finalForecast || 0);
  }

  get formattedStretchAmount() {
    return this._formatAmountShort(this.currentSummary?.stretchForecast || 0);
  }

  _formatAmountShort(amount) {
    const v = Number(amount) || 0;
    if (v >= 1000) {
      return "$" + Math.round(v / 1000).toLocaleString() + "K";
    }
    return "$" + v.toLocaleString();
  }

  // Phase C: read-only banner
  get showReadOnlyBanner() {
    return this.isHorizonReadOnly;
  }

  get horizonLabel() {
    const opt = HORIZON_OPTIONS.find((o) => o.value === this.selectedHorizon);
    return opt ? opt.label : this.selectedHorizon;
  }

  // ── Dirty tracking ──
  dirtyOverrides = new Map();
  rowDataVersionMap = new Map();
  rowErrorMap = new Map();

  // ── UI state ──
  isLoading = false;
  isSaving = false;
  isLocked = false;
  savingMessage = "";
  expandedRowId;

  // ── Drill-in ──
  isDrillIn = false;
  drillInStack = []; // { participantId, scopeId, label }

  // ── Dialog state ──
  dialogTitle = "";
  dialogMessage = "";
  dialogConfirmLabel = "";
  dialogVariant = "save";
  dialogShowPartialFull = false;
  pendingAction = null;

  // ── Filters (current applied) ──
  currentFilters = {};
  activeCategoryFilter = null; // single category selected via card click

  // ── Computed properties ──

  get cardTitle() {
    return this.title;
  }

  // Auto-hide Est. Impact column if no records have incentive data
  get hasIncentiveData() {
    if (!this.showInlineEstimator) return false;
    return this.displayRecords.some(
      (r) => r.payoutEstimate != null || r.incentiveRate != null
    );
  }

  // ── Category cards ──

  get categoryCards() {
    if (!this.config?.categories || !this.currentSummary) return [];
    const totals = this.currentSummary.categoryTotals || {};
    const counts = this.currentSummary.categoryCounts || {};
    return this.config.categories
      .filter((c) => c.isActive)
      .map((c) => {
        const apiName = c.apiName || c.name;
        const amount = totals[apiName] || 0;
        const count = counts[apiName] || 0;
        const isActive = this.activeCategoryFilter === apiName;
        const overrides = this.currentSummary?.categoryOverrides || {};
        const override = overrides[apiName];
        const hasOverride = override && override.overrideValue != null;
        return {
          name: apiName,
          apiName,
          label: c.label || c.name,
          color: c.color || "#706E6B",
          formattedAmount:
            "$" +
            (amount >= 1000
              ? Math.round(amount / 1000).toLocaleString() + "K"
              : amount.toLocaleString()),
          count,
          countLabel: count === 1 ? "1 deal" : count + " deals",
          colorStyle: "background-color: " + (c.color || "#706E6B"),
          cardClass: "category-card" + (isActive ? " cc-active" : ""),
          tooltip:
            (c.label || c.name) +
            ": $" +
            amount.toLocaleString() +
            " (" +
            count +
            " deals)",
          hasOverride,
          overrideValue: hasOverride ? override.overrideValue : null,
          overrideDelta: hasOverride
            ? override.overrideValue - (override.computedValue || 0)
            : null,
          formattedDelta: hasOverride
            ? (override.overrideValue >= (override.computedValue || 0)
                ? "+"
                : "") +
              "$" +
              Math.abs(
                override.overrideValue - (override.computedValue || 0)
              ).toLocaleString()
            : "",
          overrideByName: override?.overrideByName || "",
          overrideNotes: override?.overrideNotes || "",
          summaryId: override?.summaryId || null,
          computedAmount: override?.computedValue || amount,
          isStale: override?.isStale === true
        };
      });
  }

  // ── Attainment card ──

  get showAttainment() {
    return (
      this.currentSummary &&
      (this.currentSummary.target > 0 || this.currentSummary.achieved > 0)
    );
  }

  get formattedAttainmentPct() {
    const pct = this.currentSummary?.attainmentPct || 0;
    return Math.round(pct) + "%";
  }

  get formattedAttainmentDetail() {
    const s = this.currentSummary;
    if (!s) return "";
    const achieved = s.achieved
      ? "$" + Math.round(s.achieved / 1000).toLocaleString() + "K"
      : "$0";
    const target = s.target
      ? "$" + Math.round(s.target / 1000).toLocaleString() + "K"
      : "$0";
    return achieved + " of " + target;
  }

  get attainmentColorStyle() {
    return "background-color: " + this._attainmentColor;
  }

  get attainmentColorText() {
    return "color: " + this._attainmentColor;
  }

  get _attainmentColor() {
    const pct = this.currentSummary?.attainmentPct || 0;
    if (pct >= 100) return "#1589EE"; // Above target — blue

    // Time-aware coloring: compare attainment to expected pace
    // Expected pace = (elapsed months / total months) * 100
    const period = this.config?.currentPeriod;
    let expectedPct = 50; // default midpoint if no period info
    if (period?.startDate) {
      // Calculate fiscal year progress
      // Assume fiscal year = 12 months from first period's start month
      const now = new Date();
      const periodStart = new Date(period.startDate);
      const fiscalYearStart = new Date(periodStart.getFullYear(), 0, 1); // Jan 1
      const elapsed = (now - fiscalYearStart) / (365.25 * 24 * 60 * 60 * 1000);
      expectedPct = Math.min(elapsed * 100, 100);
    }

    // Compare actual vs expected pace
    const paceRatio = expectedPct > 0 ? pct / expectedPct : 1;

    if (paceRatio >= 0.9) return "#04844B"; // On/above pace — green
    if (paceRatio >= 0.7) return "#F2CF00"; // Slightly behind — yellow
    return "#EA001E"; // Significantly behind — red
  }

  // ── Coverage card ──

  get showCoverage() {
    return this.currentSummary?.coverageRatio != null;
  }

  get formattedCoverage() {
    const ratio = Number(this.currentSummary?.coverageRatio);
    if (!isFinite(ratio)) return "N/A";
    return ratio.toFixed(1) + "x";
  }

  get formattedCoverageDetail() {
    const s = this.currentSummary;
    if (!s || !s.remaining) return "";
    // Pipeline = sum of non-terminal category totals
    let pipeline = 0;
    if (s.categoryTotals) {
      for (const [key, val] of Object.entries(s.categoryTotals)) {
        // Exclude terminal categories (Closed_Won, Lost)
        if (key !== "Closed_Won" && key !== "Lost") {
          pipeline += val || 0;
        }
      }
    }
    const pipeStr = "$" + Math.round(pipeline / 1000).toLocaleString() + "K";
    const remStr = "$" + Math.round(s.remaining / 1000).toLocaleString() + "K";
    return pipeStr + " / " + remStr;
  }

  get coverageAmountClass() {
    const ratio = Number(this.currentSummary?.coverageRatio) || 0;
    if (ratio >= 3) return "cc-amount coverage-healthy";
    if (ratio >= 1.5) return "cc-amount coverage-caution";
    return "cc-amount coverage-low";
  }

  // ── Tier card ──

  get showTierInfo() {
    return this.currentSummary?.currentTier || this.currentSummary?.currentRate;
  }

  get formattedCurrentRate() {
    const rate = this.currentSummary?.currentRate;
    return rate != null ? rate + "%" : "";
  }

  get formattedNextTierDistance() {
    const dist = this.currentSummary?.nextTierDistance;
    if (dist == null) return "$0";
    return "$" + Math.round(dist / 1000).toLocaleString() + "K";
  }

  handleCategoryCardClick(event) {
    const category = event.currentTarget.dataset.category;
    if (this.activeCategoryFilter === category) {
      // Toggle off — show all
      this.activeCategoryFilter = null;
      this.currentFilters = { ...this.currentFilters, categoryFilter: null };
    } else {
      // Filter to this category
      this.activeCategoryFilter = category;
      this.currentFilters = {
        ...this.currentFilters,
        categoryFilter: [category]
      };
    }
    this.currentPage = 1;
    if (this.isClientSideFiltering) {
      this.applyClientSideFilters();
    } else {
      this.loadRecords();
    }
  }

  get currentParticipantId() {
    return this.context?.participant?.participantId;
  }

  get periodOptions() {
    if (!this.config || !this.config.periods) return [];
    return this.config.periods.map((p) => ({
      label: p.label + " (" + p.status + ")",
      value: p.periodId
    }));
  }

  get showScopePicker() {
    return this.context?.availableScopes?.length > 1;
  }

  get scopeOptions() {
    if (!this.context || !this.context.availableScopes) return [];
    return this.context.availableScopes.map((s) => ({
      label: s.scopeName || s.scopeId,
      value: s.scopeId
    }));
  }

  get showCurrencyToggle() {
    return this.config && this.config.currencyMode !== "Single";
  }

  get statusLabel() {
    return this.context?.submissionStatus || "Not Started";
  }

  get statusBadgeClass() {
    const status = (this.statusLabel || "").toLowerCase().replace(/\s+/g, "-");
    return "slds-badge status-badge status-" + status;
  }

  get canSubmit() {
    // Phase C: Submitting only makes sense for the current period view
    return this.context?.canSubmit && !this.isHorizonReadOnly;
  }

  get canFreeze() {
    // Phase C: Freeze only makes sense for the current period view
    return this.context?.canFreeze && !this.isHorizonReadOnly;
  }

  get submitLabel() {
    return this.context?.isBudgetMode ? "Submit Budget" : "Submit";
  }

  get freezeLabel() {
    return this.config?.topLevelActionLabel || "Freeze";
  }

  get showCopyButton() {
    return this.context?.canEdit;
  }

  get canCopyFromLevel() {
    return this.context?.hierarchyLevel > 1;
  }

  get isSaveDisabled() {
    // Phase C: Save disabled while in multi-period read-only mode.
    return (
      this.isLocked ||
      this.isHorizonReadOnly ||
      !this.context?.canEdit ||
      this.dirtyOverrides.size === 0
    );
  }

  get hasDirtyChanges() {
    return this.dirtyOverrides.size > 0;
  }

  // Phase C: combined lock — true when actively saving OR when viewing
  // a multi-period horizon (where editing is disabled by design).
  get isGridLocked() {
    return this.isLocked || this.isHorizonReadOnly;
  }

  get dirtyCountLabel() {
    const count = this.dirtyOverrides.size;
    return count + (count === 1 ? " unsaved change" : " unsaved changes");
  }

  get distinctStages() {
    const stages = new Set();
    for (const rec of this.allRecords) {
      if (rec.stage) stages.add(rec.stage);
    }
    return Array.from(stages).sort();
  }

  get breadcrumbItems() {
    const items = [{ id: "root", label: "My Forecast" }];
    for (const entry of this.drillInStack) {
      items.push({ id: entry.participantId, label: entry.label });
    }
    return items;
  }

  // ── Data loading ──

  async loadContext() {
    if (!this.selectedPeriodId) return;
    this.isLoading = true;
    try {
      this.context = await getParticipantContext({
        periodId: this.selectedPeriodId,
        scopeId: this.selectedScopeId || null
      });
      if (this.context?.availableScopes?.length > 0 && !this.selectedScopeId) {
        this.selectedScopeId = this.context.availableScopes[0].scopeId;
      }
      await this.loadRecords();
    } catch (error) {
      console.error("loadContext error:", JSON.stringify(error));
      this.showError(
        "Failed to load participant context: " +
          (error.body?.message || error.message || "")
      );
    } finally {
      this.isLoading = false;
    }
  }

  async loadRecords() {
    if (!this.selectedPeriodId || !this.currentParticipantId) return;
    this.isLoading = true;
    try {
      // Build clean request — only include non-null filter values
      const request = {
        periodId: this.selectedPeriodId,
        participantId: this.currentParticipantId,
        scopeId: this.selectedScopeId,
        pageNumber: this.currentPage,
        pageSize: this.pageSize
      };
      // Add filters only if they have values
      const f = this.currentFilters || {};
      if (f.searchText) request.searchText = f.searchText;
      if (f.categoryFilter && f.categoryFilter.length > 0)
        request.categoryFilter = f.categoryFilter;
      if (f.stageFilter && f.stageFilter.length > 0)
        request.stageFilter = f.stageFilter;
      if (f.healthBandFilter && f.healthBandFilter.length > 0)
        request.healthBandFilter = f.healthBandFilter;
      if (f.pendingApprovalOnly) request.pendingApprovalOnly = true;
      if (f.overriddenOnly) request.overriddenOnly = true;
      if (f.divergentOnly) request.divergentOnly = true;
      if (f.sortField) request.sortField = f.sortField;
      if (f.sortDirection) request.sortDirection = f.sortDirection;

      const result = await getForecastRecords({
        periodId: request.periodId,
        participantId: request.participantId,
        scopeId: request.scopeId,
        pageNumber: request.pageNumber,
        pageSize: request.pageSize,
        searchText: request.searchText || null,
        sortField: request.sortField || null,
        sortDirection: request.sortDirection || null,
        categoryFilter: request.categoryFilter || null,
        stageFilter: request.stageFilter || null,
        healthBandFilter: request.healthBandFilter || null,
        pendingApprovalOnly: request.pendingApprovalOnly || false,
        overriddenOnly: request.overriddenOnly || false,
        divergentOnly: request.divergentOnly || false,
        groupId: this.selectedGroupId || null,
        horizon: this.selectedHorizon || null
      });
      this.totalCount = result.totalCount;
      this.totalUnfilteredCount = result.totalUnfilteredCount;
      this.currentSummary = result.summary;
      this.currentPage = result.pageNumber;
      // Phase C: ForecastService marks multi-period horizons as readOnly so the
      // grid/save/submit/freeze switch off (editing across periods is unsafe).
      this.isHorizonReadOnly = result.readOnly === true;

      // Determine filtering strategy
      this.isClientSideFiltering = this.totalUnfilteredCount <= 500;

      if (this.isClientSideFiltering) {
        // Load all records for client-side filtering
        if (this.currentPage === 1 && !this.hasActiveFilters()) {
          this.allRecords = result.records || [];
        }
      }

      // Enrich records with UI state
      const records = (result.records || []).map((rec) => ({
        ...rec,
        _isExpanded: rec.recordId === this.expandedRowId,
        _isDirty: this.dirtyOverrides.has(rec.recordId),
        _rowError: this.rowErrorMap.get(rec.recordId) || null
      }));
      this.displayRecords = records;

      // Capture data versions
      for (const rec of records) {
        if (rec.dataVersion) {
          this.rowDataVersionMap.set(rec.recordId, rec.dataVersion);
        }
      }
    } catch (error) {
      console.error("loadRecords error:", JSON.stringify(error));
      this.showError(
        "Failed to load forecast records: " +
          (error.body?.message || error.message || JSON.stringify(error))
      );
    } finally {
      this.isLoading = false;
    }
  }

  hasActiveFilters() {
    const f = this.currentFilters;
    return (
      f.searchText ||
      f.categoryFilter ||
      f.stageFilter ||
      f.healthBandFilter ||
      f.overriddenOnly ||
      f.divergentOnly ||
      f.pendingApprovalOnly
    );
  }

  // ── Toolbar handlers ──

  handlePeriodChange(event) {
    this.selectedPeriodId = event.detail.value;
    this.resetState();
    this.loadContext();
  }

  handleScopeChange(event) {
    this.selectedScopeId = event.detail.value;
    this.resetState();
    this.loadRecords();
  }

  handleCurrencyToggle() {
    this.isLocalCurrency = !this.isLocalCurrency;
    sessionStorageSet("revt_currency_toggle", this.isLocalCurrency);
  }

  resetState() {
    this.dirtyOverrides.clear();
    this.rowErrorMap.clear();
    this.currentPage = 1;
    this.expandedRowId = null;
    this.currentFilters = {};
    this.isDrillIn = false;
    this.drillInStack = [];
  }

  // ── Filter handler ──

  handleFilterChange(event) {
    console.log(
      "App: handleFilterChange received",
      JSON.stringify(event.detail)
    );
    console.log(
      "App: isClientSideFiltering =",
      this.isClientSideFiltering,
      "allRecords.length =",
      this.allRecords.length
    );
    const filters = event.detail;
    this.currentFilters = {
      searchText: filters.searchText,
      categoryFilter: filters.categoryFilter,
      stageFilter: filters.stageFilter,
      healthBandFilter: filters.healthBandFilter,
      overriddenOnly: filters.overriddenOnly || false,
      divergentOnly: filters.divergentOnly || false,
      pendingApprovalOnly: filters.pendingApprovalOnly || false
    };
    this.currentPage = 1;

    if (this.isClientSideFiltering) {
      this.applyClientSideFilters();
    } else {
      this.loadRecords();
    }
  }

  applyClientSideFilters() {
    let filtered = [...this.allRecords];
    const f = this.currentFilters;

    if (f.searchText) {
      const search = f.searchText.toLowerCase();
      filtered = filtered.filter(
        (r) =>
          (r.recordName && r.recordName.toLowerCase().includes(search)) ||
          (r.ownerName && r.ownerName.toLowerCase().includes(search))
      );
    }
    if (f.categoryFilter && f.categoryFilter.length > 0) {
      filtered = filtered.filter((r) => f.categoryFilter.includes(r.category));
    }
    if (f.stageFilter && f.stageFilter.length > 0) {
      filtered = filtered.filter((r) => f.stageFilter.includes(r.stage));
    }
    if (f.healthBandFilter && f.healthBandFilter.length > 0) {
      filtered = filtered.filter((r) =>
        f.healthBandFilter.includes(r.healthBand)
      );
    }
    if (f.overriddenOnly) {
      filtered = filtered.filter((r) => r.overrideId != null);
    }
    if (f.divergentOnly) {
      filtered = filtered.filter((r) => r.crmDivergence === true);
    }
    if (f.pendingApprovalOnly) {
      filtered = filtered.filter((r) => r.pendingApproval === true);
    }

    this.totalCount = filtered.length;

    // Paginate
    const start = (this.currentPage - 1) * this.pageSize;
    const end = Math.min(start + this.pageSize, filtered.length);
    this.displayRecords = filtered.slice(start, end).map((rec) => ({
      ...rec,
      _isExpanded: rec.recordId === this.expandedRowId,
      _isDirty: this.dirtyOverrides.has(rec.recordId),
      _rowError: this.rowErrorMap.get(rec.recordId) || null
    }));
  }

  // ── Grid event handlers ──

  handleSort(event) {
    this.currentFilters.sortField = event.detail.sortField;
    this.currentFilters.sortDirection = event.detail.sortDirection;
    if (this.isClientSideFiltering) {
      this.sortClientSide(event.detail.sortField, event.detail.sortDirection);
    } else {
      this.loadRecords();
    }
  }

  sortClientSide(field, direction) {
    const dir = direction === "DESC" ? -1 : 1;
    const isDisplayField = field.startsWith("df_");
    const isMetricField = field.startsWith("metric_");
    const dfKey = isDisplayField ? field.substring(3) : null;
    this.allRecords = [...this.allRecords].sort((a, b) => {
      let va, vb;
      if (isDisplayField) {
        va = a.displayFieldValues?.[dfKey] ?? "";
        vb = b.displayFieldValues?.[dfKey] ?? "";
      } else if (isMetricField) {
        va = a.metricValues?.[field] ?? 0;
        vb = b.metricValues?.[field] ?? 0;
      } else {
        va = a[field] ?? "";
        vb = b[field] ?? "";
      }
      if (va < vb) return -1 * dir;
      if (va > vb) return 1 * dir;
      return 0;
    });
    this.applyClientSideFilters();
  }

  handlePageChange(event) {
    this.currentPage = event.detail.pageNumber;
    if (this.isClientSideFiltering) {
      this.applyClientSideFilters();
    } else {
      this.loadRecords();
    }
  }

  handleRowChange(event) {
    console.log("App: handleRowChange received", JSON.stringify(event.detail));
    const { recordId, field, value } = event.detail;
    if (!this.dirtyOverrides.has(recordId)) {
      const rec = this.displayRecords.find((r) => r.recordId === recordId);
      this.dirtyOverrides.set(recordId, {
        recordId: rec?.recordId,
        overrideId: rec?.overrideId,
        category: rec?.category,
        metricValues: { ...(rec?.metricValues || {}) },
        closeDateOverride: rec?.closeDateOverride,
        comment: rec?.comment,
        dataVersion: this.rowDataVersionMap.get(recordId)
      });
    }
    const dirty = this.dirtyOverrides.get(recordId);
    if (field === "category") {
      dirty.category = value;
    } else if (field === "closeDateOverride") {
      dirty.closeDateOverride = value;
    } else if (field.startsWith("metric_")) {
      if (!dirty.metricValues) dirty.metricValues = {};
      dirty.metricValues[field] = value;
    }
    // Re-render dirty state
    this.displayRecords = this.displayRecords.map((r) => ({
      ...r,
      _isDirty: this.dirtyOverrides.has(r.recordId)
    }));
  }

  handleToggleExpand(event) {
    const { recordId } = event.detail;
    this.expandedRowId = this.expandedRowId === recordId ? null : recordId;
    this.displayRecords = this.displayRecords.map((r) => ({
      ...r,
      _isExpanded: r.recordId === this.expandedRowId
    }));
  }

  // ── Drill-in ──

  async handleOwnerDrillIn(event) {
    const { recordId, ownerName } = event.detail;
    // Find the ownerId from the record
    const rec = this.displayRecords.find((r) => r.recordId === recordId);
    if (!rec || !rec.ownerId) {
      this.showToast(
        "warning",
        "Drill-in",
        "Owner information not available for this record."
      );
      return;
    }

    // Don't drill into yourself
    if (!this.isDrillIn && rec.ownerId === this.context?.participant?.userId) {
      return;
    }

    this.isLoading = true;
    try {
      // Find the subordinate's participant record
      const subordinateParticipantId = await getParticipantIdForUser({
        userId: rec.ownerId,
        periodId: this.selectedPeriodId
      });

      if (!subordinateParticipantId) {
        this.showToast(
          "warning",
          "Drill-in",
          (ownerName || "This user") +
            " is not a forecast participant for this period."
        );
        return;
      }

      // Push current state to drill-in stack
      this.drillInStack = [
        ...this.drillInStack,
        {
          participantId: this.currentParticipantId,
          scopeId: this.selectedScopeId,
          label: ownerName || "User"
        }
      ];
      this.isDrillIn = true;

      // Load subordinate's context (with security check)
      this.context = await getParticipantContextForUser({
        participantId: subordinateParticipantId,
        periodId: this.selectedPeriodId,
        scopeId: this.selectedScopeId
      });

      // Reset filters and page for new view
      this.currentPage = 1;
      this.dirtyOverrides.clear();
      this.expandedRowId = null;

      await this.loadRecords();
    } catch (error) {
      const msg = error.body?.message || error.message || "";
      if (msg.includes("permission") || msg.includes("Insufficient")) {
        this.showToast(
          "error",
          "Access Denied",
          "You do not have permission to view this participant's forecast."
        );
        // Pop the breadcrumb we just pushed
        this.drillInStack = this.drillInStack.slice(0, -1);
        if (this.drillInStack.length === 0) {
          this.isDrillIn = false;
        }
      } else {
        this.showError("Drill-in failed: " + msg);
      }
    } finally {
      this.isLoading = false;
    }
  }

  async handleBreadcrumbClick(event) {
    const targetId = event.detail.name;

    if (targetId === "root") {
      // Pop all — return to own forecast
      this.isDrillIn = false;
      this.drillInStack = [];
      this.dirtyOverrides.clear();
      this.expandedRowId = null;
      this.currentPage = 1;
      await this.loadContext();
      return;
    }

    // Pop to the clicked level
    const idx = this.drillInStack.findIndex(
      (e) => e.participantId === targetId
    );
    if (idx >= 0) {
      // Navigate to the clicked participant
      const target = this.drillInStack[idx];
      this.drillInStack = this.drillInStack.slice(0, idx);
      this.isDrillIn = this.drillInStack.length > 0;
      this.dirtyOverrides.clear();
      this.expandedRowId = null;
      this.currentPage = 1;

      this.isLoading = true;
      try {
        this.context = await getParticipantContextForUser({
          participantId: target.participantId,
          periodId: this.selectedPeriodId,
          scopeId: target.scopeId || this.selectedScopeId
        });
        await this.loadRecords();
      } catch (error) {
        this.showError(
          "Navigation failed: " + (error.body?.message || error.message)
        );
      } finally {
        this.isLoading = false;
      }
    }
  }

  // ── Save ──

  handleSaveClick() {
    if (this.dirtyOverrides.size === 0) return;
    this.dialogTitle = "Save Forecast";
    this.dialogMessage = `Save ${this.dirtyOverrides.size} edited record(s)?`;
    this.dialogConfirmLabel = "Save";
    this.dialogVariant = "save";
    this.dialogShowPartialFull = this.dirtyOverrides.size < this.totalCount;
    this.pendingAction = "save";
    this.template.querySelector("c-revt-confirmation-dialog").open();
  }

  handleSubmitClick() {
    this.dialogTitle = this.context?.isBudgetMode
      ? "Submit Budget"
      : "Submit Forecast";
    this.dialogMessage = "Submit forecast to the next level for review?";
    this.dialogConfirmLabel = this.submitLabel;
    this.dialogVariant = "submit";
    this.dialogShowPartialFull = false;
    this.pendingAction = "submit";
    this.template.querySelector("c-revt-confirmation-dialog").open();
  }

  handleFreezeClick() {
    this.dialogTitle = this.freezeLabel;
    this.dialogMessage = `This will ${this.freezeLabel.toLowerCase()} all overrides in scope "${this.selectedScopeId}". This action cannot be undone without admin intervention.`;
    this.dialogConfirmLabel = this.freezeLabel;
    this.dialogVariant = "freeze";
    this.dialogShowPartialFull = false;
    this.pendingAction = "freeze";
    this.template.querySelector("c-revt-confirmation-dialog").open();
  }

  async handleDialogConfirm() {
    const action = this.pendingAction;
    this.pendingAction = null;
    if (action === "save") {
      await this.executeSave();
    } else if (action === "submit") {
      await this.executeSubmit();
    } else if (action === "freeze") {
      await this.executeFreeze();
    }
  }

  handleDialogCancel() {
    this.pendingAction = null;
  }

  async executeSave() {
    const overrides = Array.from(this.dirtyOverrides.values());
    if (overrides.length === 0) return;

    this.isSaving = true;
    this.isLocked = true;
    const chunks = chunkArray(overrides, SAVE_CHUNK_SIZE);
    let totalSaved = 0;
    const allErrors = [];

    try {
      for (let i = 0; i < chunks.length; i++) {
        this.savingMessage = `Saving batch ${i + 1} of ${chunks.length}...`;
        // eslint-disable-next-line no-await-in-loop
        const result = await saveForecastData({
          overridesJson: JSON.stringify(chunks[i]),
          periodId: this.selectedPeriodId,
          participantId: this.currentParticipantId,
          isPartial: false
        });
        if (result.success) {
          totalSaved += result.updatedOverrideIds.length;
          // Clear saved rows from dirty map
          for (const dto of chunks[i]) {
            this.dirtyOverrides.delete(dto.recordId);
            this.rowErrorMap.delete(dto.recordId);
          }
        } else {
          // Process errors per §17.13
          for (const err of result.errors) {
            const parsed = parseErrorPrefix(err);
            if (parsed.category === "CONFLICT" && parsed.recordId) {
              this.rowErrorMap.set(parsed.recordId, parsed.details);
            }
            allErrors.push(err);
          }
        }
      }

      if (allErrors.length > 0) {
        console.error("Save errors:", JSON.stringify(allErrors));
        this.showToast(
          "warning",
          "Partial Save",
          `${totalSaved} saved. ${allErrors.length} error(s): ${allErrors.join(" | ")}`
        );
      } else {
        this.showToast("success", "Saved", `${totalSaved} override(s) saved.`);
      }

      await this.loadRecords();
    } catch (error) {
      this.showError("Save failed: " + (error.body?.message || error.message));
    } finally {
      this.isSaving = false;
      this.isLocked = false;
      this.savingMessage = "";
    }
  }

  async executeSubmit() {
    this.isSaving = true;
    this.isLocked = true;
    this.savingMessage = "Submitting forecast...";

    try {
      // Save dirty rows first
      if (this.dirtyOverrides.size > 0) {
        await this.executeSave();
      }

      const result = await submitForecastData({
        overridesJson: "[]",
        periodId: this.selectedPeriodId,
        participantId: this.currentParticipantId,
        isPartial: false,
        validateCompleteness: false,
        freezeExchangeRates: true
      });

      if (result.success) {
        this.showToast(
          "success",
          "Submitted",
          `Forecast submitted. Snapshot: ${result.snapshotId || "N/A"}`
        );
      } else {
        this.showToast("error", "Submit Failed", result.errors.join("; "));
      }

      await this.loadContext();
    } catch (error) {
      this.showError(
        "Submit failed: " + (error.body?.message || error.message)
      );
    } finally {
      this.isSaving = false;
      this.isLocked = false;
      this.savingMessage = "";
    }
  }

  async executeFreeze() {
    this.isSaving = true;
    this.isLocked = true;
    this.savingMessage = "Freezing scope...";

    try {
      const result = await freezeForecastData({
        periodId: this.selectedPeriodId,
        scopeId: this.selectedScopeId
      });

      if (result.success) {
        this.showToast(
          "success",
          "Frozen",
          `${result.frozenCount} override(s) frozen. ${result.expiredGovernanceCount} governance event(s) expired.`
        );
      } else {
        this.showToast("error", "Freeze Failed", result.errors.join("; "));
      }

      await this.loadContext();
    } catch (error) {
      this.showError(
        "Freeze failed: " + (error.body?.message || error.message)
      );
    } finally {
      this.isSaving = false;
      this.isLocked = false;
      this.savingMessage = "";
    }
  }

  // ── Copy ──

  async handleCopySelect(event) {
    const value = event.detail.value; // e.g., 'level_OVERWRITE' or 'last_MERGE'
    const [source, mode] = value.split("_");
    this.isLocked = true;
    this.isLoading = true;

    try {
      let result;
      if (source === "level") {
        result = await copyFromPreviousLevel({
          periodId: this.selectedPeriodId,
          participantId: this.currentParticipantId,
          scopeId: this.selectedScopeId,
          copyMode: mode
        });
      } else {
        result = await copyFromLastForecast({
          periodId: this.selectedPeriodId,
          participantId: this.currentParticipantId,
          scopeId: this.selectedScopeId,
          copyMode: mode
        });
      }

      if (result.success) {
        this.showToast(
          "success",
          "Copied",
          `${result.copiedCount} copied, ${result.skippedCount} skipped, ${result.skippedEditedCount} skipped (edited).`
        );
      } else {
        this.showToast("error", "Copy Failed", result.errors.join("; "));
      }

      this.dirtyOverrides.clear();
      await this.loadRecords();
    } catch (error) {
      this.showError("Copy failed: " + (error.body?.message || error.message));
    } finally {
      this.isLocked = false;
      this.isLoading = false;
    }
  }

  // ── CSV Export ──

  handleExportSelect(event) {
    const format = event.detail.value;
    if (format === "csv") {
      this._exportAs("csv");
    } else if (format === "xlsx") {
      this._exportAs("xlsx");
    }
  }

  async _exportAs(format) {
    try {
      const { headers, rows } = this._buildExportData();
      const csvContent = this._buildCsvString(headers, rows);
      const dateStr = new Date().toISOString().slice(0, 10);
      const baseName = "Forecast_Export_" + dateStr;

      if (format === "csv") {
        this._downloadDataUri(csvContent, baseName + ".csv", "text/csv");
      } else if (format === "xlsx") {
        // Build simple XML spreadsheet (Excel 2003 XML format — no library needed)
        const xlsContent = this._buildExcelXml(headers, rows);
        this._downloadDataUri(
          xlsContent,
          baseName + ".xls",
          "application/vnd.ms-excel"
        );
      }
    } catch (error) {
      this.showError(
        "Export failed: " + (error.body?.message || error.message || error)
      );
    }
  }

  _buildExportData() {
    const records =
      this.allRecords.length > 0 ? this.allRecords : this.displayRecords;
    const headers = [
      "Deal Name",
      "Owner",
      "Stage",
      "Close Date",
      "CRM Amount",
      "Health Score",
      "Health Band"
    ];
    // Dynamic metric headers
    const metricDefs = (this.config?.metrics || []).filter((m) => m.isEditable);
    for (const m of metricDefs) {
      headers.push(m.label || m.name);
    }
    headers.push(
      "Category",
      "Override Close Date",
      "Status",
      "Comment",
      "CRM Divergence",
      "Divergence Details"
    );

    const rows = records.map((r) => {
      const cells = [
        r.recordName || "",
        r.ownerName || "",
        r.stage || "",
        r.closeDate || "",
        r.crmAmount != null ? r.crmAmount : "",
        r.healthScore != null ? r.healthScore : "",
        r.healthBand || ""
      ];
      for (let idx = 1; idx <= metricDefs.length; idx++) {
        const val = r.metricValues ? r.metricValues["metric_" + idx] : null;
        cells.push(val != null ? val : "");
      }
      cells.push(
        r.category || "",
        r.closeDateOverride || "",
        r.status || "",
        r.comment || "",
        r.crmDivergence ? "Yes" : "",
        r.crmDivergenceDetails || ""
      );
      return cells;
    });
    return { headers, rows };
  }

  _buildCsvString(headers, rows) {
    const esc = (v) => {
      if (v == null) return "";
      const s = String(v);
      return s.includes(",") || s.includes('"') || s.includes("\n")
        ? '"' + s.replace(/"/g, '""') + '"'
        : s;
    };
    const lines = [headers.map(esc).join(",")];
    for (const row of rows) {
      lines.push(row.map(esc).join(","));
    }
    return lines.join("\n");
  }

  _buildExcelXml(headers, rows) {
    const escXml = (v) => {
      if (v == null) return "";
      return String(v)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
    };
    let xml = '<?xml version="1.0"?>\n';
    xml += '<?mso-application progid="Excel.Sheet"?>\n';
    xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n';
    xml += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';
    xml += '<Styles><Style ss:ID="Bold"><Font ss:Bold="1"/></Style>';
    xml +=
      '<Style ss:ID="Num"><NumberFormat ss:Format="#,##0"/></Style></Styles>\n';
    xml += '<Worksheet ss:Name="Forecast"><Table>\n';
    // Header row
    xml += '<Row ss:StyleID="Bold">';
    for (const h of headers) {
      xml += '<Cell><Data ss:Type="String">' + escXml(h) + "</Data></Cell>";
    }
    xml += "</Row>\n";
    // Data rows
    for (const row of rows) {
      xml += "<Row>";
      for (const cell of row) {
        const isNum = cell !== "" && !isNaN(cell);
        const type = isNum ? "Number" : "String";
        const style = isNum ? ' ss:StyleID="Num"' : "";
        xml +=
          "<Cell" +
          style +
          '><Data ss:Type="' +
          type +
          '">' +
          escXml(cell) +
          "</Data></Cell>";
      }
      xml += "</Row>\n";
    }
    xml += "</Table></Worksheet></Workbook>";
    return xml;
  }

  _downloadDataUri(content, fileName, mimeType) {
    const encodedUri =
      "data:" + mimeType + ";charset=utf-8," + encodeURIComponent(content);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", fileName);
    link.style.display = "none";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  // ── Phase D: Summary override handlers ──

  handleSummaryOverride(event) {
    const { summaryId, overrideValue, notes } = event.detail;
    overrideSummaryValue({ summaryId, overrideValue, notes })
      .then(() => {
        this.showToast(
          "success",
          "Override Saved",
          "Category forecast updated."
        );
        this.loadRecords();
      })
      .catch((err) => {
        this.showError(
          "Override failed: " + (err.body?.message || err.message)
        );
      });
  }

  handleSummaryClear(event) {
    const { summaryId } = event.detail;
    clearSummaryOverride({ summaryId })
      .then(() => {
        this.showToast(
          "success",
          "Override Cleared",
          "Reverted to pipeline computed value."
        );
        this.loadRecords();
      })
      .catch((err) => {
        this.showError("Clear failed: " + (err.body?.message || err.message));
      });
  }

  // ── Toast helpers ──

  showToast(variant, title, message) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  showError(message) {
    this.showToast("error", "Error", message);
  }

  // ── Admin navigation ──

  navigateToAdmin() {
    this[NavigationMixin.Navigate]({
      type: "standard__navItemPage",
      attributes: {
        apiName: "REVT__REVT_Admin"
      }
    });
  }
}
