import { createElement } from "lwc";
import RevtConfirmationDialog from "c/revtConfirmationDialog";

// Helper to flush all pending promises
function flushPromises() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-revt-confirmation-dialog", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("is hidden by default", () => {
    const element = createElement("c-revt-confirmation-dialog", {
      is: RevtConfirmationDialog
    });
    document.body.appendChild(element);

    const modal = element.shadowRoot.querySelector('section[role="dialog"]');
    expect(modal).toBeNull();
  });

  it("renders dialog when isOpen is true", async () => {
    const element = createElement("c-revt-confirmation-dialog", {
      is: RevtConfirmationDialog
    });
    element.title = "Test Title";
    element.message = "Test Message";
    document.body.appendChild(element);

    // Call open() AFTER appending to trigger re-render
    element.open();
    await flushPromises();

    const modal = element.shadowRoot.querySelector('section[role="dialog"]');
    expect(modal).not.toBeNull();
    expect(modal.textContent).toContain("Test Title");
  });

  it("dispatches confirm event on confirm button click", async () => {
    const element = createElement("c-revt-confirmation-dialog", {
      is: RevtConfirmationDialog
    });
    element.variant = "save";
    element.confirmLabel = "Save";
    document.body.appendChild(element);

    const handler = jest.fn();
    element.addEventListener("confirm", handler);

    element.open();
    await flushPromises();

    // Find all lightning-button elements and click the one that is not "Cancel"
    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    const confirmBtn = Array.from(buttons).find((b) => b.label !== "Cancel");
    expect(confirmBtn).not.toBeNull();
    confirmBtn.click();
    await flushPromises();

    expect(handler).toHaveBeenCalledTimes(1);
    expect(handler.mock.calls[0][0].detail.variant).toBe("save");
  });

  it("dispatches cancel event on cancel button click", async () => {
    const element = createElement("c-revt-confirmation-dialog", {
      is: RevtConfirmationDialog
    });
    document.body.appendChild(element);

    const handler = jest.fn();
    element.addEventListener("cancel", handler);

    element.open();
    await Promise.resolve();

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    const cancelBtn = Array.from(buttons).find((b) => b.label === "Cancel");
    expect(cancelBtn).not.toBeNull();
    cancelBtn.click();
    await flushPromises();

    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("closes after confirm", async () => {
    const element = createElement("c-revt-confirmation-dialog", {
      is: RevtConfirmationDialog
    });
    document.body.appendChild(element);

    element.open();
    await flushPromises();
    expect(
      element.shadowRoot.querySelector('section[role="dialog"]')
    ).not.toBeNull();

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    const confirmBtn = Array.from(buttons).find((b) => b.label !== "Cancel");
    confirmBtn.click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector('section[role="dialog"]')
    ).toBeNull();
  });

  it("shows freeze warning when variant is freeze", async () => {
    const element = createElement("c-revt-confirmation-dialog", {
      is: RevtConfirmationDialog
    });
    element.variant = "freeze";
    element.confirmLabel = "Freeze";
    element.message = "Freeze all overrides?";
    document.body.appendChild(element);

    element.open();
    await flushPromises();

    const modal = element.shadowRoot.querySelector('section[role="dialog"]');
    expect(modal).not.toBeNull();

    // Verify the warning text exists somewhere in the modal
    const allText = modal.textContent;
    expect(allText).toContain("cannot be undone");
  });
});
