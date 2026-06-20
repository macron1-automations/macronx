import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "selectAll", "actionButton"]
  static values = {
    processModalUrl: String,
    tagModalUrl: String,
    archiveUrl: String,
    unarchiveUrl: String,
    destroyUrl: String
  }

  connect() {
    this.updateActions()
  }

  selectAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
    })
    this.updateActions()
  }

  updateActions() {
    const anyChecked = this.checkboxTargets.some(cb => cb.checked)
    this.actionButtonTargets.forEach(btn => {
      btn.disabled = !anyChecked
    })

    if (this.hasSelectAllTarget) {
      const allChecked = this.checkboxTargets.length > 0 &&
        this.checkboxTargets.every(cb => cb.checked)
      this.selectAllTarget.checked = allChecked
      this.selectAllTarget.indeterminate = anyChecked && !allChecked
    }
  }

  get selectedIds() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }

  openBulkProcess() {
    const ids = this.selectedIds
    if (ids.length === 0) return

    const params = new URLSearchParams()
    ids.forEach(id => params.append("inbox_ids[]", id))

    const frame = document.querySelector("turbo-frame#modal")
    if (frame) {
      frame.src = `${this.processModalUrlValue}?${params.toString()}`
    }
  }

  openBulkTag() {
    const ids = this.selectedIds
    if (ids.length === 0) return

    const params = new URLSearchParams()
    ids.forEach(id => params.append("inbox_ids[]", id))

    const frame = document.querySelector("turbo-frame#modal")
    if (frame) {
      frame.src = `${this.tagModalUrlValue}?${params.toString()}`
    }
  }

  bulkUnarchive() {
    const ids = this.selectedIds
    if (ids.length === 0) return

    const count = ids.length
    const message = `Restore ${count} item${count === 1 ? "" : "s"} to inbox?`
    if (!confirm(message)) return

    this.submitBulkForm(this.unarchiveUrlValue, "patch", ids)
  }

  bulkArchive() {
    const ids = this.selectedIds
    if (ids.length === 0) return

    const count = ids.length
    const message = `Archive ${count} item${count === 1 ? "" : "s"}? This will move them to the archive.`
    if (!confirm(message)) return

    this.submitBulkForm(this.archiveUrlValue, "patch", ids)
  }

  bulkDelete() {
    const ids = this.selectedIds
    if (ids.length === 0) return

    const count = ids.length
    const message = `Permanently delete ${count} item${count === 1 ? "" : "s"}? This cannot be undone.`
    if (!confirm(message)) return

    this.submitBulkForm(this.destroyUrlValue, "delete", ids)
  }

  submitBulkForm(url, method, ids) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = url

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrfToken) {
      const csrf = document.createElement("input")
      csrf.type = "hidden"
      csrf.name = "authenticity_token"
      csrf.value = csrfToken
      form.appendChild(csrf)
    }

    const methodOverride = document.createElement("input")
    methodOverride.type = "hidden"
    methodOverride.name = "_method"
    methodOverride.value = method
    form.appendChild(methodOverride)

    ids.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "inbox_ids[]"
      input.value = id
      form.appendChild(input)
    })

    document.body.appendChild(form)
    form.submit()
  }
}
