import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getParticipants from "@salesforce/apex/AdminConsoleController.getParticipants";
import syncParticipants from "@salesforce/apex/AdminConsoleController.syncParticipants";
import updateParticipantLevel from "@salesforce/apex/AdminConsoleController.updateParticipantLevel";
import refreshLevelLabels from "@salesforce/apex/AdminConsoleController.refreshLevelLabels";

const PAGE_SIZE = 25;
const ACTIONS = [{ label: "Delegate", name: "delegate" }];

export default class RevtAdminParticipants extends LightningElement {
  @api configId;
  @api periods = [];

  participants = [];
  draftValues = [];
  isLoading = false;
  selectedPeriodId = "";
  currentPage = 1;
  totalCount = 0;

  columns = [
    { label: "Name", fieldName: "userName" },
    { label: "Email", fieldName: "userEmail" },
    {
      label: "Level",
      fieldName: "REVT__Hierarchy_Level__c",
      type: "number",
      editable: true
    },
    { label: "Scope", fieldName: "_scopeLabel" },
    { label: "Status", fieldName: "REVT__Submission_Status__c" },
    { type: "action", typeAttributes: { rowActions: ACTIONS } }
  ];

  get periodOptions() {
    return (this.periods || []).map((p) => ({ label: p.Name, value: p.Id }));
  }
  get hasParticipants() {
    return this.participants.length > 0;
  }
  get isFirstPage() {
    return this.currentPage <= 1;
  }
  get isLastPage() {
    return this.currentPage * PAGE_SIZE >= this.totalCount;
  }

  handlePeriodChange(event) {
    this.selectedPeriodId = event.detail.value;
    this.currentPage = 1;
    this.loadParticipants();
  }

  async loadParticipants() {
    if (!this.selectedPeriodId) return;
    this.isLoading = true;
    try {
      const result = await getParticipants({
        periodId: this.selectedPeriodId,
        pageSize: PAGE_SIZE,
        pageNumber: this.currentPage
      });
      // Flatten relationship fields for datatable
      this.participants = (result.participants || []).map((p) => ({
        ...p,
        userName: p.REVT__User__r?.Name || p.User__r?.Name || "",
        userEmail: p.REVT__User__r?.Email || p.User__r?.Email || "",
        _scopeLabel:
          p.REVT__Scope_Name__c ||
          p.Scope_Name__c ||
          p.REVT__Scope_Id__c ||
          p.Scope_Id__c ||
          ""
      }));
      this.totalCount = result.totalCount || 0;
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isLoading = false;
    }
  }

  async handleInlineSave(event) {
    const drafts = event.detail.draftValues;
    try {
      for (const draft of drafts) {
        // eslint-disable-next-line no-await-in-loop
        await updateParticipantLevel({
          participantId: draft.Id,
          newLevel: draft.REVT__Hierarchy_Level__c
        });
      }
      this.showToast("Success", "Participant level updated", "success");
      this.draftValues = [];
      this.loadParticipants();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  handleRowAction(event) {
    const row = event.detail.row;
    if (event.detail.action.name === "delegate") {
      this.dispatchEvent(
        new CustomEvent("delegate", { detail: { participantId: row.Id } })
      );
    }
  }

  async handleSync() {
    if (!this.selectedPeriodId) {
      this.showToast("Warning", "Please select a period first.", "warning");
      return;
    }
    this.isLoading = true;
    try {
      await syncParticipants({ periodId: this.selectedPeriodId });
      this.showToast("Success", "Participants synced", "success");
      this.loadParticipants();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Phase C: Re-runs hierarchy discovery and updates Level_Labels__c.
   * Auto-derived levels refresh to current org values; admin overrides
   * (autoDerive=false) are preserved.
   */
  async handleRefreshLevels() {
    if (!this.configId) {
      this.showToast("Error", "No active configuration found.", "error");
      return;
    }
    this.isLoading = true;
    try {
      // Apex returns the updated Level_Labels__c JSON string. Count the entries
      // for a friendlier toast.
      const updatedJson = await refreshLevelLabels({ configId: this.configId });
      let levelCount = 0;
      try {
        const parsed = updatedJson ? JSON.parse(updatedJson) : [];
        if (Array.isArray(parsed)) levelCount = parsed.length;
        // eslint-disable-next-line no-unused-vars
      } catch (e) {
        // ignore parse errors \u2014 toast still shows generic message
      }
      const message =
        levelCount > 0
          ? `${levelCount} level label(s) refreshed from hierarchy.`
          : "Level labels refreshed from hierarchy.";
      this.showToast("Refreshed", message, "success");
      // Tell parent admin app to reload config so the labels refresh in cards
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast(
        "Refresh Failed",
        error.body?.message ||
          error.message ||
          "Unable to refresh level labels.",
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  handlePrevious() {
    this.currentPage--;
    this.loadParticipants();
  }
  handleNext() {
    this.currentPage++;
    this.loadParticipants();
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
