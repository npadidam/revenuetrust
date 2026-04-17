import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import discoverOrg from "@salesforce/apex/OnboardingController.discoverOrg";
import hasActiveConfig from "@salesforce/apex/OnboardingController.hasActiveConfig";
import activateConfiguration from "@salesforce/apex/OnboardingController.activateConfiguration";

const STEP_LABELS = [
  { value: "1", label: "Discovery" },
  { value: "2", label: "Hierarchy" },
  { value: "3", label: "Pipeline" },
  { value: "4", label: "Stages" },
  { value: "5", label: "Metrics" },
  { value: "6", label: "Categories" },
  { value: "7", label: "Periods" },
  { value: "8", label: "Currency" },
  { value: "9", label: "Levels" },
  { value: "10", label: "Fields" },
  { value: "11", label: "Attainment" },
  { value: "12", label: "Activate" }
];

export default class RevtOnboardingWizard extends LightningElement {
  @track currentStep = 1;
  @track discovery = null;
  @track isLoading = true;
  @track isActivating = false;
  @track isReconfigureMode = false;

  // All wizard state accumulated across steps
  @track wizardData = {
    // Step 2: Hierarchy
    hierarchySource: "Ownership",
    // Step 2: Custom field scope (only used when hierarchySource = Custom_Field)
    scopeCustomObject: "Opportunity",
    scopeCustomField: null,
    // Step 3: Pipeline
    pipelineRecordTypeFilter: null,
    // Step 3 Phase B: Grouping mode + groups list
    // groupingMode: 'Single' | 'RecordType' | 'OppCustomField' | 'ChildCustomField'
    groupingMode: "Single",
    // groupingSourceObject + groupingField only when groupingMode is OppCustomField or ChildCustomField
    groupingSourceObject: null,
    groupingLookupField: null,
    groupingField: null,
    // Phase B groups: each = { name, type, recordTypeNames[], values[], sortOrder, overrideStages, closedWonStages[], closedLostStages[] }
    groups: [
      {
        name: "All Opportunities",
        type: "All",
        recordTypeNames: [],
        values: [],
        sortOrder: 1,
        overrideStages: false,
        closedWonStages: [],
        closedLostStages: []
      }
    ],
    // Step 4: Terminal stages (config-level defaults)
    closedWonStages: [],
    closedLostStages: [],
    // Step 5: Metrics
    metrics: [
      {
        name: "Revenue",
        label: "Revenue",
        metricType: "Currency",
        displayFormat: "Currency",
        isPrimary: true,
        isRequired: true,
        isEditable: true,
        sortOrder: 1,
        sourceField: "Amount",
        // Phase B: multi-source object support (Opportunity is the default)
        sourceObject: "Opportunity",
        sourceLookupField: null,
        aggregation: null,
        // Phase B Gap 2: structured filter clauses (max 5)
        filters: []
      }
    ],
    // Step 6: Categories
    categoryTemplate: "standard",
    categories: [
      {
        name: "Commit",
        label: "Commit",
        apiName: "Commit",
        color: "#04844B",
        countsTowardTarget: true,
        countsTowardStretch: true,
        isTerminal: false,
        isHighConfidence: true,
        regressionWarning: false,
        sortOrder: 1
      },
      {
        name: "Best Case",
        label: "Best Case",
        apiName: "Best_Case",
        color: "#1589EE",
        countsTowardTarget: true,
        countsTowardStretch: true,
        isTerminal: false,
        isHighConfidence: false,
        regressionWarning: false,
        sortOrder: 2
      },
      {
        name: "Pipeline",
        label: "Pipeline",
        apiName: "Pipeline",
        color: "#F2CF00",
        countsTowardTarget: false,
        countsTowardStretch: false,
        isTerminal: false,
        isHighConfidence: false,
        regressionWarning: false,
        sortOrder: 3
      },
      {
        name: "Closed Won",
        label: "Closed Won",
        apiName: "Closed_Won",
        color: "#706E6B",
        countsTowardTarget: true,
        countsTowardStretch: true,
        isTerminal: true,
        isHighConfidence: true,
        regressionWarning: false,
        sortOrder: 4
      },
      {
        name: "Lost",
        label: "Lost",
        apiName: "Lost",
        color: "#EA001E",
        countsTowardTarget: false,
        countsTowardStretch: false,
        isTerminal: true,
        isHighConfidence: false,
        regressionWarning: true,
        sortOrder: 5
      }
    ],
    // Step 6 Phase C: Final / Stretch UI labels
    finalForecastLabel: "Final Forecast",
    stretchForecastLabel: "Stretch Forecast",
    // Step 7: Periods
    periodType: "Monthly",
    futurePeriods: 3,
    fiscalYearStartMonth: 1,
    // Step 7 Phase C: past periods + horizon
    pastPeriodsVisible: 2,
    defaultHorizon: "Current_Period",
    customHorizonPeriods: 3,
    // Step 8: Currency
    currencyMode: "Single",
    corporateCurrency: "USD",
    // Step 9 Phase C: Per-level labels with autoDerive flag.
    // Array of { level, label, autoDerive }. Populated from discovery on connectedCallback.
    levelLabels: [],
    // Phase D: Forecast Cadence
    forecastCadence: null,
    submissionDeadlineDay: null,
    autoFreezeOnDeadline: false,
    cadenceAnchorDate: null,
    // Step 10: Display Fields
    displayFields: [],
    // Step 11: Attainment
    attainmentSource: "Forecast_Quota_With_Live",
    // General
    configName: "Default Configuration",
    topLevelLockLabel: "Freeze",
    paginationSize: 40
  };

  get steps() {
    return STEP_LABELS;
  }

  get currentStepValue() {
    return String(this.currentStep);
  }

  get isFirstStep() {
    return this.currentStep <= 1;
  }

  get isLastStep() {
    return this.currentStep >= 12;
  }

  get showDiscovery() {
    return !this.isLoading && this.currentStep >= 1 && this.currentStep <= 3;
  }

  get showMetricsCategories() {
    return this.currentStep >= 4 && this.currentStep <= 6;
  }

  get showSettings() {
    return this.currentStep >= 7 && this.currentStep <= 9;
  }

  get showActivate() {
    return this.currentStep >= 10 && this.currentStep <= 12;
  }

  async connectedCallback() {
    try {
      // Check if already configured (reconfigure mode)
      this.isReconfigureMode = await hasActiveConfig();

      // Run org discovery
      this.discovery = await discoverOrg();

      // Auto-populate from discovery
      if (this.discovery) {
        this.wizardData.closedWonStages = this.discovery.closedWonStages || [];
        this.wizardData.closedLostStages =
          this.discovery.closedLostStages || [];
        this.wizardData.fiscalYearStartMonth =
          this.discovery.fiscalYearStartMonth || 1;
        this.wizardData.currencyMode = this.discovery.isMultiCurrency
          ? "MultiWithDatedRates"
          : "Single";
        if (this.discovery.corporateCurrency) {
          this.wizardData.corporateCurrency = this.discovery.corporateCurrency;
        }

        // Phase C: per-level array with autoDerive=true defaults (vs legacy Map<level,label>)
        if (this.discovery.detectedLevels) {
          this.wizardData.levelLabels = this.discovery.detectedLevels.map(
            (lvl) => ({
              level: lvl.level,
              label: lvl.suggestedLabel,
              autoDerive: true
            })
          );
        }
      }
    } catch (err) {
      this.showToast(
        "error",
        "Discovery Failed",
        err.body?.message || err.message
      );
    } finally {
      this.isLoading = false;
    }
  }

  // ── Navigation ──

  handleNext() {
    // Phase A: Step 8 is now shown as read-only for single-currency orgs
    // (educational context, not skipped)
    this.currentStep = Math.min(this.currentStep + 1, 12);
  }

  handleBack() {
    this.currentStep = Math.max(this.currentStep - 1, 1);
  }

  // ── Step data changes from child components ──

  handleStepDataChange(event) {
    const { field, value } = event.detail;
    this.wizardData = { ...this.wizardData, [field]: value };
  }

  // ── Activation ──

  async handleActivate() {
    this.isActivating = true;
    try {
      const d = this.wizardData;
      const configId = await activateConfiguration({
        configName: d.configName,
        hierarchySource: d.hierarchySource,
        periodType: d.periodType,
        futurePeriods: d.futurePeriods,
        fiscalYearStartMonth: d.fiscalYearStartMonth,
        attainmentSource: d.attainmentSource,
        currencyMode: d.currencyMode,
        corporateCurrency: d.corporateCurrency,
        topLevelLockLabel: d.topLevelLockLabel,
        paginationSize: d.paginationSize,
        pipelineRecordTypeFilter: d.pipelineRecordTypeFilter,
        levelLabelsJson: JSON.stringify(d.levelLabels),
        metricsJson: JSON.stringify(d.metrics),
        categoriesJson: JSON.stringify(d.categories),
        scopeCustomObject: d.scopeCustomObject,
        scopeCustomField: d.scopeCustomField,
        // Phase B: groupsJson built from Step 3 grouping state.
        // Auto-created "All Opportunities" group is the default when groupingMode = 'Single'.
        groupsJson: this._buildGroupsJson(d),
        // Phase C: past periods + horizon defaults + Final/Stretch labels
        pastPeriodsVisible: d.pastPeriodsVisible,
        defaultHorizon: d.defaultHorizon,
        customHorizonPeriods: d.customHorizonPeriods,
        finalForecastLabel: d.finalForecastLabel,
        stretchForecastLabel: d.stretchForecastLabel,
        // Phase D: Forecast Cadence
        forecastCadence: d.forecastCadence,
        submissionDeadlineDay: d.submissionDeadlineDay,
        autoFreezeOnDeadline: d.autoFreezeOnDeadline,
        cadenceAnchorDate:
          d.forecastCadence === "Bi_Weekly"
            ? new Date().toISOString().split("T")[0]
            : null,
        displayFieldsJson:
          d.displayFields && d.displayFields.length > 0
            ? JSON.stringify(d.displayFields)
            : null
      });

      this.showToast(
        "success",
        "Forecasting Activated!",
        "Your forecast is ready. Redirecting to the Forecast tab..."
      );

      // Notify parent to switch from wizard to grid
      this.dispatchEvent(new CustomEvent("activate", { detail: { configId } }));
    } catch (err) {
      this.showToast(
        "error",
        "Activation Failed",
        err.body?.message || err.message
      );
    } finally {
      this.isActivating = false;
    }
  }

  showToast(variant, title, message) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  /**
   * Build the groupsJson payload sent to OnboardingController.activateConfiguration.
   * Returns null when there's nothing to send (Apex auto-creates "All Opportunities").
   */
  _buildGroupsJson(d) {
    if (!d || !d.groups || d.groups.length === 0) {
      return null;
    }
    // Default single group case
    if (d.groupingMode === "Single" && d.groups.length === 1) {
      return JSON.stringify([
        {
          name: d.groups[0].name || "All Opportunities",
          groupType: "All",
          sortOrder: 1,
          overrideStages: false
        }
      ]);
    }
    const isRT = d.groupingMode === "RecordType";
    const isCustomField =
      d.groupingMode === "OppCustomField" ||
      d.groupingMode === "ChildCustomField";
    const out = d.groups.map((g, idx) => {
      const base = {
        name: g.name || "Group " + (idx + 1),
        sortOrder: g.sortOrder || idx + 1,
        overrideStages: g.overrideStages === true,
        closedWonStages:
          g.closedWonStages && g.closedWonStages.length
            ? g.closedWonStages.join(",")
            : null,
        closedLostStages:
          g.closedLostStages && g.closedLostStages.length
            ? g.closedLostStages.join(",")
            : null
      };
      if (isRT) {
        return {
          ...base,
          groupType: "Record_Type",
          recordTypeNames:
            g.recordTypeNames && g.recordTypeNames.length
              ? g.recordTypeNames.join(",")
              : null
        };
      }
      if (isCustomField) {
        return {
          ...base,
          groupType: "Custom_Field",
          groupSourceObject: d.groupingSourceObject,
          groupLookupField: d.groupingLookupField,
          groupField: d.groupingField,
          groupFieldValues:
            g.values && g.values.length ? g.values.join(",") : null
        };
      }
      return { ...base, groupType: "All" };
    });
    return JSON.stringify(out);
  }
}
