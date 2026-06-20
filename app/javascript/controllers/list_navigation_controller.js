import { Controller } from "@hotwired/stimulus"

// Provides vim-style j/k navigation, x selection, and Enter-to-view for list views.
// Mount on the container that holds the rows. Mark each row with
// data-list-navigation-target="row" and each "View" link with data-list-navigation-view.
export default class extends Controller {
  static targets = ["row"]

  connect() {
    this.currentIndex = -1
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleTurboLoad = this.handleTurboLoad.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    // turbo:load fires once per visit after the final render (not on the cache
    // preview), so it's the right place to restore focus across navigations.
    document.addEventListener("turbo:load", this.handleTurboLoad)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("turbo:load", this.handleTurboLoad)
  }

  handleTurboLoad() {
    this.restoreIndex()
  }

  handleKeydown(event) {
    const focused = event.target
    if (focused.isContentEditable) return
    if (focused.tagName === "TEXTAREA" || focused.tagName === "SELECT") return
    if (focused.tagName === "INPUT") {
      const textTypes = ["text", "email", "password", "search", "url", "tel",
                         "number", "date", "time", "datetime-local", "month", "week"]
      if (textTypes.includes(focused.type)) return
    }
    if (event.ctrlKey || event.metaKey || event.altKey) return

    const rows = this.rowTargets
    if (rows.length === 0) return

    switch (event.key) {
      case "j":
        event.preventDefault()
        this.moveTo(Math.min(this.currentIndex + 1, rows.length - 1))
        break
      case "k":
        event.preventDefault()
        if (this.currentIndex <= 0) {
          this.moveTo(0)
        } else {
          this.moveTo(this.currentIndex - 1)
        }
        break
      case "x":
        if (this.currentIndex < 0) return
        event.preventDefault()
        this.toggleCheckbox(rows[this.currentIndex])
        break
      case "Enter":
        if (this.currentIndex < 0) return
        event.preventDefault()
        this.viewRow(rows[this.currentIndex])
        break
    }
  }

  moveTo(newIndex) {
    const rows = this.rowTargets
    if (this.currentIndex >= 0 && rows[this.currentIndex]) {
      this.deactivate(rows[this.currentIndex])
    }
    this.currentIndex = newIndex
    if (rows[newIndex]) {
      this.activate(rows[newIndex])
      rows[newIndex].scrollIntoView({ block: "nearest" })
    }
  }

  activate(row) {
    row.classList.add("bg-indigo-50")
    row.classList.remove("hover:bg-gray-50")
    row.dataset.listNavigationActive = "true"
  }

  deactivate(row) {
    row.classList.remove("bg-indigo-50")
    row.classList.add("hover:bg-gray-50")
    delete row.dataset.listNavigationActive
  }

  toggleCheckbox(row) {
    const checkbox = row.querySelector('[data-bulk-actions-target="checkbox"]')
    if (!checkbox) return
    checkbox.checked = !checkbox.checked
    checkbox.dispatchEvent(new Event("change", { bubbles: true }))
  }

  restoreIndex() {
    const saved = sessionStorage.getItem("list-navigation-index")
    if (saved === null) return
    sessionStorage.removeItem("list-navigation-index")
    const index = parseInt(saved, 10)
    if (isNaN(index) || index < 0) return
    if (index < this.rowTargets.length) this.moveTo(index)
  }

  viewRow(row) {
    const link = row.querySelector("[data-list-navigation-view]")
    if (!link) return
    sessionStorage.setItem("list-navigation-index", this.currentIndex)
    link.click()
  }
}
