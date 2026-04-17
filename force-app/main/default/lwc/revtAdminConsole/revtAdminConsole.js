import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getConfig from "@salesforce/apex/AdminConsoleController.getConfig";
import getPeriods from "@salesforce/apex/AdminConsoleController.getPeriods";

export default class RevtAdminConsole extends LightningElement {
  @track config;
  @track periods = [];
  isLoading = true;
  activeTab = "general";

  async connectedCallback() {
    await this.loadData();
  }

  async loadData() {
    this.isLoading = true;
    try {
      this.config = await getConfig();

      console.log(
        "AdminConsole: getConfig returned",
        JSON.stringify(this.config)
      );
      if (this.config) {
        this.periods = await getPeriods({ configId: this.config.Id });
      }
    } catch (err) {
      this.showToast("error", "Error", err.body?.message || err.message);
    } finally {
      this.isLoading = false;
    }
  }

  handleTabChange(event) {
    this.activeTab = event.target.value;
  }

  async handleConfigSaved() {
    await this.loadData();
    this.showToast("success", "Saved", "Configuration updated successfully.");
  }

  showToast(variant, title, message) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
