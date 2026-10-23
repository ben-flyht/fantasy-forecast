import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    event.preventDefault()

    const form = this.element
    const params = new URLSearchParams()
    const teamId = new FormData(form).get("team_id")
    if (teamId) params.set("team_id", teamId)
    this.appendPrice(params, form)

    const path = params.toString() ? `${form.action}?${params}` : form.action
    Turbo.visit(path, { frame: "rankings_container", action: "advance" })
  }

  appendPrice(params, form) {
    const min = form.querySelector("input[name='min_price']")
    const max = form.querySelector("input[name='max_price']")
    if (min && parseFloat(min.value) > parseFloat(min.min)) params.set("min_price", min.value)
    if (max && parseFloat(max.value) < parseFloat(max.max)) params.set("max_price", max.value)
  }
}
