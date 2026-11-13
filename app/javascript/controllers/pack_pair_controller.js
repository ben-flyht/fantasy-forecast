import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["choice"]

  choose(event) {
    this.choiceTargets.forEach((choice) => {
      const state = choice === event.currentTarget ? "kept" : "passed"
      choice.classList.remove("pack-choice--kept", "pack-choice--passed")
      choice.classList.add(`pack-choice--${state}`)
      choice.dataset.packChoice = state
    })
  }
}
