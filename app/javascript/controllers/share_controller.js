import { Controller } from "@hotwired/stimulus"

// Sharing a page the way people actually share one: the phone's own share sheet
// where there is one, and the clipboard where there is not.
//
// The URL shared is the page's canonical, not the address in the bar, so a filtered
// view or a stray query string is never what lands in somebody's group chat.
export default class extends Controller {
  static values = { url: String, title: String }
  static targets = ["label"]

  RESTORE_AFTER = 2000

  async share(event) {
    event.preventDefault()

    if (navigator.share) {
      try {
        await navigator.share({ title: this.titleValue, url: this.urlValue })
        return
      } catch (error) {
        // Dismissing the sheet is an answer, not a failure to fall back from.
        if (error.name === "AbortError") return
      }
    }

    this.copy()
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.urlValue)
      this.say("Link copied")
    } catch {
      this.say("Could not copy")
    }
  }

  say(message) {
    if (!this.hasLabelTarget) return

    this.original ??= this.labelTarget.textContent
    this.labelTarget.textContent = message
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.labelTarget.textContent = this.original }, this.RESTORE_AFTER)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
