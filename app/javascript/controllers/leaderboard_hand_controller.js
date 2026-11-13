import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "title", "summary", "body"]

  open(event) {
    const row = event.currentTarget.closest("[data-pack-row]")
    const hand = row.querySelector("[data-pack-row-hand-template]").content.cloneNode(true)

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
