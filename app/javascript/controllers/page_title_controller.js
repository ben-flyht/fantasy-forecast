import { Controller } from "@hotwired/stimulus"

// Changing position swaps the rankings frame and pushes a new URL, but Turbo only
// rewrites the frame: the <title> in the head keeps whatever the first render said.
// So the address bar reads /gameweeks/1/defenders while the tab, the history entry
// and the analytics page title all still say Forwards.
//
// Attach this inside the frame and the title comes back into step every time the
// frame is replaced, because a new element connects on each swap.
export default class extends Controller {
  static values = { text: String }

  connect() {
    if (this.hasTextValue && this.textValue !== document.title) {
      document.title = this.textValue
    }
  }
}
