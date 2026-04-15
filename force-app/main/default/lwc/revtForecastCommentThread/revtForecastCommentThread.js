import { LightningElement, api } from "lwc";
import getLastForecastComment from "@salesforce/apex/ForecastController.getLastForecastComment";
import saveForecastComment from "@salesforce/apex/ForecastController.saveForecastComment";
import userId from "@salesforce/user/Id";

export default class RevtForecastCommentThread extends LightningElement {
  @api recordId;
  @api overrideId;
  @api periodId;
  @api readOnly = false;

  comments = [];
  isLoading = false;
  newCommentText = "";
  newCommentType = "Note";

  get commentTypeOptions() {
    return [
      { label: "Note", value: "Note" },
      { label: "Escalation", value: "Escalation" },
      { label: "Question", value: "Question" }
    ];
  }

  get commentCount() {
    return this.comments ? this.comments.length : 0;
  }

  get hasComments() {
    return this.comments && this.comments.length > 0;
  }

  get showEmpty() {
    return !this.isLoading && (!this.comments || this.comments.length === 0);
  }

  get canAddComment() {
    return !this.readOnly && this.recordId;
  }

  get isPostDisabled() {
    return !this.newCommentText || !this.newCommentText.trim();
  }

  connectedCallback() {
    this.loadComments();
  }

  async loadComments() {
    if (!this.recordId) return;
    this.isLoading = true;
    try {
      const result = await getLastForecastComment({
        recordId: this.recordId,
        userId: userId
      });
      this.comments = (result || []).map((c) => ({
        ...c,
        formattedDate: this.formatDate(c.commentDate),
        typeClass: this.getTypeClass(c.commentType)
      }));
    } catch {
      // ignored
      this.comments = [];
    } finally {
      this.isLoading = false;
    }
  }

  handleTypeChange(event) {
    this.newCommentType = event.detail.value;
  }

  handleTextChange(event) {
    this.newCommentText = event.detail.value;
  }

  async handlePost() {
    if (!this.newCommentText || !this.newCommentText.trim()) return;

    try {
      const commentText = this.newCommentText.trim();
      const commentType = this.newCommentType;

      const commentId = await saveForecastComment({
        overrideId: this.overrideId,
        periodId: this.periodId,
        recordId: this.recordId,
        comment: commentText,
        commentType
      });

      // Optimistic UI — add new comment to local list immediately
      // (avoids cacheable=true stale response from reloading)
      this.comments = [
        {
          commentId,
          author: "You",
          level: null,
          commentDate: new Date().toISOString(),
          formattedDate: this.formatDate(new Date().toISOString()),
          comment: commentText,
          commentType,
          typeClass: this.getTypeClass(commentType)
        },
        ...this.comments
      ];

      this.newCommentText = "";
      this.newCommentType = "Note";

      this.dispatchEvent(
        new CustomEvent("commentadded", {
          detail: { commentId }
        })
      );
    } catch (error) {
      // Show error inline — parent handles toast
      this.dispatchEvent(
        new CustomEvent("commenterror", {
          detail: { message: error.body ? error.body.message : error.message }
        })
      );
    }
  }

  formatDate(dt) {
    if (!dt) return "";
    try {
      const d = new Date(dt);
      return d.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        hour: "numeric",
        minute: "2-digit"
      });
    } catch {
      // ignored
      return String(dt);
    }
  }

  getTypeClass(commentType) {
    const base = "slds-badge slds-m-left_xx-small";
    if (commentType === "Escalation") return base + " slds-theme_error";
    if (commentType === "Question") return base + " slds-theme_warning";
    return base + " slds-badge_lightest";
  }
}
