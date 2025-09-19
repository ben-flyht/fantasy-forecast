import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    console.log("Prediction form controller connected")
    this.updateStyling()
  }

  submitForm(event) {
    const form = event.target.closest("form")
    if (form) {
      console.log("Submitting form via requestSubmit")
      form.requestSubmit()
    }
  }

  // Called after Turbo updates the frame
  turboFrameRendered() {
    console.log("Turbo frame rendered, updating styling")
    this.updateStyling()
  }

  updateStyling() {
    this.selectTargets.forEach(select => {
      const hasSelection = select.value && select.value !== ""

      if (hasSelection) {
        select.classList.remove("border-gray-300")
        select.classList.add("border-green-500", "bg-green-50")
      } else {
        select.classList.remove("border-green-500", "bg-green-50")
        select.classList.add("border-gray-300")
      }
    })
  }
}