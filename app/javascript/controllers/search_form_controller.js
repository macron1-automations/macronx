import { Controller } from "@hotwired/stimulus"

// Debounces form submission on input so the inbox search filters
// automatically as the user types, without needing to press Enter.
// After each Turbo navigation the controller reconnects; connect()
// restores focus to the query input so typing is uninterrupted.
export default class extends Controller {
  initialize() {
    this._debouncedSubmit = this.debounce(this._doSubmit.bind(this), 400)
  }

  connect() {
    if (sessionStorage.getItem("inbox-search-refocus")) {
      sessionStorage.removeItem("inbox-search-refocus")
      const input = this.queryInput
      // Use setTimeout(0) so focus runs after Turbo finishes rendering.
      setTimeout(() => {
        input.focus()
        input.setSelectionRange(input.value.length, input.value.length)
      }, 0)
    }
  }

  onInput() {
    this._debouncedSubmit()
  }

  _doSubmit() {
    sessionStorage.setItem("inbox-search-refocus", "1")
    this.element.requestSubmit()
  }

  get queryInput() {
    return this.element.querySelector('input[name="query"]')
  }

  debounce(fn, delay) {
    let timeout
    return (...args) => {
      clearTimeout(timeout)
      timeout = setTimeout(() => fn(...args), delay)
    }
  }
}
