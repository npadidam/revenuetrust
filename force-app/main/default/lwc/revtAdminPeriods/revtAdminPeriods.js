import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getPeriods from "@salesforce/apex/AdminConsoleController.getPeriods";
import updatePeriodStatus from "@salesforce/apex/AdminConsoleController.updatePeriodStatus";
import generateFuturePeriods from "@salesforce/apex/AdminConsoleController.generateFuturePeriods";

// eslint-disable-next-line no-unused-vars
const ACTIONS = [
  { label: "Open Early", name: "open_early" },
  { label: "Close", name: "close" },
  { label: "Reopen", name: "reopen" }
];

export default class RevtAdminPeriods extends LightningElement {
  @api configId;

  periods = [];
  isLoading = false;

  columns = [
    { label: "Period Name", fieldName: "Name" },
    { label: "Start Date", fieldName: "REVT__Start_Date__c", type: "date" },
    { label: "End Date", fieldName: "REVT__End_Date__c", type: "date" },
    {
      label: "Status",
      fieldName: "REVT__Status__c",
      cellAttributes: {
        class: { fieldName: "statusClass" }
      }
    },
    { type: "action", typeAttributes: { rowActions: this.getRowActions } }
  ];

  connectedCallback() {
    this.loadPeriods();
  }

  getRowActions(row, doneCallback) {
    const actions = [];
    const status = row.REVT__Status__c;
    if (status === "Planned")
      actions.push({ label: "Open Early", name: "open_early" });
    if (status === "Open") actions.push({ label: "Close", name: "close" });
    if (status === "Closed") actions.push({ label: "Reopen", name: "reopen" });
    doneCallback(actions);
  }

  async loadPeriods() {
    this.isLoading = true;
    try {
      const data = await getPeriods({ configId: this.configId });
      this.periods = data.map((p) => ({
        ...p,
        statusClass:
          p.REVT__Status__c === "Open"
            ? "slds-text-color_success"
            : p.REVT__Status__c === "Closed"
              ? "slds-text-color_error"
              : ""
      }));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isLoading = false;
    }
  }

  async handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;
    const statusMap = { open_early: "Open", close: "Closed", reopen: "Open" };
    try {
      await updatePeriodStatus({
        periodId: row.Id,
        newStatus: statusMap[actionName]
      });
      this.showToast(
        "Success",
        `Period ${actionName.replace("_", " ")} successful`,
        "success"
      );
      this.loadPeriods();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  async handleGeneratePeriods() {
    this.isLoading = true;
    try {
      await generateFuturePeriods({ configId: this.configId });
      this.showToast("Success", "Future periods generated", "success");
      this.loadPeriods();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isLoading = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
