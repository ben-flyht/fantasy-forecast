import { Controller } from "@hotwired/stimulus"

const KEEP_MS = 450
const OPEN_MS = 750
const COUNT_MS = 1100
const CELEBRATE_AT = 90
const CONFETTI = ["#f59e0b", "#fde68a", "#18181b", "#ef4444", "#22c55e", "#3b82f6", "#ec4899"]

export default class extends Controller {
  static targets = ["sealed", "stage", "choice", "score"]
  static values = { dealMs: { type: Number, default: 1400 } }

  connect() {
    this.still = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (this.hasScoreTarget && !this.still) this.scoreTarget.textContent = "0%"
    if (!this.hasSealedTarget) this.deal()
  }

  disconnect() {
    clearTimeout(this.dealing)
    cancelAnimationFrame(this.counting)
  }

  charge() {
    if (this.hasSealedTarget && !this.still) this.sealedTarget.classList.add("is-charging")
  }

  open(event) {
    event?.preventDefault()
    if (this.opened || !this.hasSealedTarget) return

    this.opened = true
    const sealed = this.sealedTarget
    sealed.classList.remove("is-charging")
    sealed.classList.add("is-open")
    setTimeout(() => {
      sealed.remove()
      this.stageTarget.hidden = false
      this.deal()
    }, this.still ? 0 : OPEN_MS)
  }

  deal() {
    if (!this.hasStageTarget) return

    this.stageTarget.hidden = false
    this.stageTarget.classList.add("is-dealt")
    this.animating = !this.still
    this.dealing = setTimeout(() => this.settle(), this.still ? 0 : this.dealMsValue)
  }

  settle() {
    this.animating = false
    this.countUp()
  }

  skip(event) {
    if (!this.animating) return

    event.preventDefault()
    event.stopPropagation()
    clearTimeout(this.dealing)
    this.stageTarget.classList.add("is-instant")
    this.settle()
  }

  pick(event) {
    event.preventDefault()
    if (this.picking) return

    const card = event.currentTarget
    const href = card.dataset.packHref
    this.picking = true

    if (this.still) return window.Turbo.visit(href)

    this.stageTarget.classList.add("is-picking")
    card.classList.add("is-kept")
    this.choiceTargets.filter((choice) => choice !== card).forEach((choice) => choice.classList.add("is-discarded"))
    setTimeout(() => window.Turbo.visit(href), KEEP_MS)
  }

  countUp() {
    if (!this.hasScoreTarget || this.counted) return

    this.counted = true
    const score = this.scoreTarget
    const target = Number(score.dataset.packScore)
    const land = () => {
      score.textContent = `${target}%`
      score.classList.add("is-landed")
      if (target >= CELEBRATE_AT) this.celebrate(target)
    }

    if (this.still) return land()

    const started = performance.now()
    const step = (now) => {
      const progress = Math.min((now - started) / COUNT_MS, 1)
      score.textContent = `${Math.round(target * (1 - Math.pow(1 - progress, 3)))}%`
      if (progress < 1) {
        this.counting = requestAnimationFrame(step)
      } else {
        land()
      }
    }
    this.counting = requestAnimationFrame(step)
  }

  celebrate(score) {
    if (this.still) return

    const burst = document.createElement("div")
    burst.className = "pack-confetti"
    burst.setAttribute("aria-hidden", "true")
    const pieces = score >= 100 ? 90 : 45
    for (let i = 0; i < pieces; i++) {
      const piece = document.createElement("span")
      const angle = Math.random() * Math.PI * 2
      const reach = 140 + Math.random() * 260
      piece.style.background = CONFETTI[i % CONFETTI.length]
      piece.style.setProperty("--x", `${Math.cos(angle) * reach}px`)
      piece.style.setProperty("--y", `${Math.sin(angle) * reach + 160}px`)
      piece.style.setProperty("--r", `${Math.random() * 720 - 360}deg`)
      piece.style.animationDelay = `${Math.random() * 120}ms`
      burst.appendChild(piece)
    }
    document.body.appendChild(burst)
    setTimeout(() => burst.remove(), 2000)
  }
}
