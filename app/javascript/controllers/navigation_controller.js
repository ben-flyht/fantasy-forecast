import { Controller } from "@hotwired/stimulus"

// The menu behind the button, for screens too narrow to carry the links in a row.
//
// Nothing is remembered between pages on purpose: Turbo replaces the body on every
// visit, so following a link closes the menu without being asked to.
export default class extends Controller {
  static targets = ["menu", "button"]

  toggle() {
    this.expanded = !this.expanded
  }

  close() {
    this.expanded = false
  }

  closeOnOutsideClick(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  get expanded() {
    return !this.menuTarget.classList.contains("hidden")
  }

  set expanded(open) {
    this.menuTarget.classList.toggle("hidden", !open)
    this.buttonTarget.setAttribute("aria-expanded", open)
  }
}
