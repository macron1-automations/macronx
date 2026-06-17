import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  toggle() {
    this.panelTarget.classList.toggle("hidden")
  }

  show() {
    this.panelTarget.classList.remove("hidden")
  }

  hide() {
    this.panelTarget.classList.add("hidden")
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.panelTarget.classList.add("hidden")
    }
  }
}
