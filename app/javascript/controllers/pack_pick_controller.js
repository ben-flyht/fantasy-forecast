import { Controller } from "@hotwired/stimulus"

const KEEP_MS = 380
const TICK_MS = 250
const REVEAL_MS = 1750

export default class extends Controller {
  static targets = ["card", "clock", "bar"]
  static values = { forfeit: String, method: String, seconds: { type: Number, default: 10 } }

  connect() {
    const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.revealing = setTimeout(() => this.start(), still ? 0 : REVEAL_MS)
  }

  start() {
    this.revealed = true
    this.element.dataset.packRevealed = "true"
    this.endsAt = Date.now() + this.secondsValue * 1000
    if (this.hasBarTarget) {
      this.barTarget.style.transitionDuration = `${this.secondsValue}s`
      requestAnimationFrame(() => requestAnimationFrame(() => this.barTarget.classList.add("is-running")))
    }
    this.ticking = setInterval(() => this.tick(), TICK_MS)
    this.tick()
  }

  disconnect() {
    clearTimeout(this.revealing)
    clearInterval(this.ticking)
  }

  tick() {
    const left = Math.max(0, Math.ceil((this.endsAt - Date.now()) / 1000))
    if (this.hasClockTarget) this.clockTarget.textContent = left
    if (left > 0 || this.picked) return

    this.picked = true
    clearInterval(this.ticking)
    this.go(this.forfeitValue)
  }

  keep(event) {
    if (this.picked || !this.revealed) return event.preventDefault()
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button > 0) return

    event.preventDefault()
    const kept = event.currentTarget
    this.picked = true
    clearInterval(this.ticking)
    kept.classList.add("is-kept")
    this.cardTargets.filter((card) => card !== kept).forEach((card) => card.classList.add("is-discarded"))
    setTimeout(() => this.go(kept.href), KEEP_MS)
  }

  go(url) {
    if (this.methodValue !== "post") return window.Turbo.visit(url)

    const form = document.createElement("form")
    form.method = "post"
    form.action = url
    const token = document.querySelector("meta[name=csrf-token]")
    if (token) {
      const field = document.createElement("input")
      field.type = "hidden"
      field.name = "authenticity_token"
      field.value = token.content
      form.appendChild(field)
    }
    document.body.appendChild(form)
    form.requestSubmit()
  }
}
