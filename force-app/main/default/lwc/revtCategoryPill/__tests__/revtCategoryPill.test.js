import { createElement } from "lwc";
import RevtCategoryPill from "c/revtCategoryPill";

describe("c-revt-category-pill", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders with label and color", () => {
    const element = createElement("c-revt-category-pill", {
      is: RevtCategoryPill
    });
    element.label = "Commit";
    element.color = "#04844B";
    document.body.appendChild(element);

    const pill = element.shadowRoot.querySelector(".category-pill");
    expect(pill).not.toBeNull();
    expect(pill.textContent).toBe("Commit");
    expect(pill.getAttribute("style")).toContain("#04844B");
  });

  it("applies terminal class when isTerminal", () => {
    const element = createElement("c-revt-category-pill", {
      is: RevtCategoryPill
    });
    element.label = "Closed Won";
    element.color = "#706E6B";
    element.isTerminal = true;
    document.body.appendChild(element);

    const pill = element.shadowRoot.querySelector(".category-pill");
    expect(pill.classList.contains("terminal")).toBe(true);
  });

  it("uses default color when none provided", () => {
    const element = createElement("c-revt-category-pill", {
      is: RevtCategoryPill
    });
    element.label = "Pipeline";
    document.body.appendChild(element);

    const pill = element.shadowRoot.querySelector(".category-pill");
    expect(pill.getAttribute("style")).toContain("#706E6B");
  });
});
