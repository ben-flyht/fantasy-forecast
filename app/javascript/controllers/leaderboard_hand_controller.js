import { Controller } from "@hotwired/stimulus"

const DESKTOP = "(min-width: 640px)"

export default class extends Controller {
  static targets = ["dialog", "title", "summary", "body"]

  open(event) {
    if (window.matchMedia(DESKTOP).matches) return

    const row = event.currentTarget.closest("[data-pack-row]")
    const hand = row.querySelector("[data-pack-row-hand]").cloneNode(true)
    hand.classList.remove("hidden")
    hand.classList.add("grid")

    this.titleTarget.textContent = row.dataset.packRowName
    this.summaryTarget.textContent = row.dataset.packRowSummary
    this.bodyTarget.replaceChildren(hand)
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
