import { Controller } from "@hotwired/stimulus"

const KEEP_MS = 380
const TICK_MS = 250

export default class extends Controller {
  static targets = ["card", "clock", "bar"]
  static values = { forfeit: String, seconds: { type: Number, default: 10 } }

  connect() {
    this.endsAt = Date.now() + this.secondsValue * 1000
    if (this.hasBarTarget) {
      this.barTarget.style.transitionDuration = `${this.secondsValue}s`
      requestAnimationFrame(() => requestAnimationFrame(() => this.barTarget.classList.add("is-running")))
    }
    this.ticking = setInterval(() => this.tick(), TICK_MS)
    this.tick()
  }

  disconnect() {
    clearInterval(this.ticking)
  }

  tick() {
    const left = Math.max(0, Math.ceil((this.endsAt - Date.now()) / 1000))
    if (this.hasClockTarget) this.clockTarget.textContent = left
    if (left > 0 || this.picked) return

    this.picked = true
    clearInterval(this.ticking)
    window.Turbo.visit(this.forfeitValue)
  }

  keep(event) {
    if (this.picked) return event.preventDefault()
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button > 0) return

    event.preventDefault()
    const kept = event.currentTarget
    this.picked = true
    clearInterval(this.ticking)
    kept.classList.add("is-kept")
    this.cardTargets.filter((card) => card !== kept).forEach((card) => card.classList.add("is-discarded"))
    setTimeout(() => window.Turbo.visit(kept.href), KEEP_MS)
  }
}
