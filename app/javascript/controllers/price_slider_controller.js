import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["min", "max", "range", "label"]

  connect() {
    this.paint()
  }

  onInput(event) {
    this.enforceOrder(event.target)
    this.paint()
  }

  commit() {
    this.element.closest("form").requestSubmit()
  }

  enforceOrder(changed) {
    const min = parseFloat(this.minTarget.value)
    const max = parseFloat(this.maxTarget.value)
    if (min <= max) return

    if (changed === this.minTarget) {
      this.minTarget.value = max
    } else {
      this.maxTarget.value = min
    }
  }

  paint() {
    const floor = parseFloat(this.minTarget.min)
    const ceil = parseFloat(this.minTarget.max)
    const min = parseFloat(this.minTarget.value)
    const max = parseFloat(this.maxTarget.value)
    const span = ceil - floor || 1

    this.rangeTarget.style.left = `${((min - floor) / span) * 100}%`
    this.rangeTarget.style.right = `${((ceil - max) / span) * 100}%`
    this.labelTarget.textContent = `£${min.toFixed(1)}m – £${max.toFixed(1)}m`
  }
}
