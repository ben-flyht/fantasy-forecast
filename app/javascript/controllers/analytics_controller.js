import { Controller } from "@hotwired/stimulus"

export function track(name, params = {}) {
  if (typeof window.gtag === "function") window.gtag("event", name, params)
}

export default class extends Controller {
  track(event) {
    const { event: name, ...params } = event.params
    if (name) track(name, params)
  }
}
