import { Controller } from "@hotwired/stimulus"

// Provides keyboard shortcuts for the inbox views.
// Add data-keyboard-shortcuts-target="trigger" and data-keyboard-shortcuts-key="<key>"
// to any clickable element to bind it to a shortcut.
// Press ? to show/hide the shortcuts help overlay.
export default class extends Controller {
  static targets = ["trigger", "help"]

  connect() {
    this.shortcutMap = {}
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    this.buildShortcutMap()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  // Called when trigger targets are added/removed dynamically (e.g. Turbo updates)
  triggerTargetConnected() {
    this.buildShortcutMap()
  }

  triggerTargetDisconnected() {
    this.buildShortcutMap()
  }

  buildShortcutMap() {
    this.shortcutMap = {}
    this.triggerTargets.forEach(el => {
      const key = el.dataset.keyboardShortcutsKey
      if (key) this.shortcutMap[key] = el
    })
  }

  handleKeydown(event) {
    const focused = event.target
    // Ignore modifier combos (allow plain Shift only for ?)
    if (event.ctrlKey || event.metaKey || event.altKey) return

    const textTypes = ["text", "email", "password", "search", "url", "tel",
                       "number", "date", "time", "datetime-local", "month", "week"]
    const inTextField = focused.isContentEditable ||
      focused.tagName === "TEXTAREA" ||
      (focused.tagName === "INPUT" && textTypes.includes(focused.type))

    // Escape: blur any focused text/textarea so other shortcuts become available;
    // or close the help overlay if nothing is focused in a field.
    if (event.key === "Escape") {
      if (inTextField) {
        event.preventDefault()
        focused.blur()
      } else if (this.hasHelpTarget) {
        this.hideHelp()
      }
      return
    }

    // All other shortcuts are disabled while typing in a text-entry field or select.
    if (inTextField || focused.tagName === "SELECT") return

    if (event.key === "?") {
      event.preventDefault()
      this.toggleHelp()
      return
    }

    const trigger = this.shortcutMap[event.key]
    if (!trigger) return

    event.preventDefault()

    // Skip disabled elements
    if (trigger.disabled || trigger.getAttribute("aria-disabled") === "true") return

    trigger.click()
  }

  toggleHelp() {
    if (!this.hasHelpTarget) return
    const hidden = this.helpTarget.classList.contains("hidden")
    hidden ? this.showHelp() : this.hideHelp()
  }

  showHelp() {
    this.helpTarget.classList.remove("hidden")
    this.helpTarget.setAttribute("aria-hidden", "false")
  }

  hideHelp() {
    this.helpTarget.classList.add("hidden")
    this.helpTarget.setAttribute("aria-hidden", "true")
  }

  // Close help when clicking the backdrop (not the modal panel itself)
  closeHelp(event) {
    if (event.target === this.helpTarget) {
      this.hideHelp()
    }
  }
}
