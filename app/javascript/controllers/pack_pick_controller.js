import { Controller } from "@hotwired/stimulus"

const KEEP_MS = 380

export default class extends Controller {
  static targets = ["card"]

  keep(event) {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button > 0) return

    event.preventDefault()
    if (this.picked) return

    const kept = event.currentTarget
    this.picked = true
    kept.classList.add("is-kept")
    this.cardTargets.filter((card) => card !== kept).forEach((card) => card.classList.add("is-discarded"))
    setTimeout(() => window.Turbo.visit(kept.href), KEEP_MS)
  }
}
