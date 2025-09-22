import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    console.log("Forecast form controller connected")
  }

  submitForm(event) {
    const form = event.target.closest("form")
    if (form) {
      console.log("Submitting form via requestSubmit")
      form.requestSubmit()
    }
  }
}