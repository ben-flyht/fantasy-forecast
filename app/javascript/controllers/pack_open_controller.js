import { Controller } from "@hotwired/stimulus"

const TEAR = 450
const DEAL = 1150

export default class extends Controller {
  static targets = ["pack", "board", "deck", "button"]

  open() {
    const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.buttonTarget.disabled = true
    this.packTarget.classList.add("is-tearing")
    setTimeout(() => this.packTarget.classList.add("is-revealing"), still ? 0 : TEAR)
    setTimeout(() => this.deal(), still ? 0 : DEAL)
  }

  deal() {
    this.element.querySelector("[data-pack-opener]").hidden = true
    this.boardTarget.hidden = false
    this.deckTarget.classList.add("pack-reveal", "pack-deal")
  }
}
