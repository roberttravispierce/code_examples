import { Modal } from "tailwindcss-stimulus-components";
export default class extends Modal {
  static targets = ['container'];
  connect() {
    super.connect();
  }
  open(e) {
    if (this.preventDefaultActionOpening) {
      e.preventDefault();
    }
    e.target.blur();
    // Lock the scroll and save current scroll position
    this.lockScroll();

    // Unhide the modal
    document.addEventListener("serialProposalForm:load", () => {
      this.containerTarget.classList.remove(this.toggleClass);
    });

    // Insert the background
    if (!this.data.get("disable-backdrop")) {
      document.body.insertAdjacentHTML('beforeend', this.backgroundHtml);
      this.background = document.querySelector(`#${this.backgroundId}`);
    }
  }
  _backgroundHTML() {
    return '<div id="modal-background" class="fixed top-0 left-0 z-40 w-full h-full" style="background-color: rgba(1, 78, 114, 0.9);"></div>';
  }
}
