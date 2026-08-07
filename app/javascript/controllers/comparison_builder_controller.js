import { Controller } from "@hotwired/stimulus"

// Two boxes, a list of names under whichever one you are typing in, and a button
// that takes you to the argument.
//
// The pair is assembled here and the address is built from the two chosen players,
// in whatever order they were picked: /compare answers the same question either way
// round and redirects to its own spelling of it.
export default class extends Controller {
  static targets = ["input", "results", "chosen", "clear", "submit", "hint"]
  static values = { url: String }

  // How long to wait after the last keystroke before asking. Short enough to feel
  // immediate, long enough that typing a name is one request rather than eight.
  static DEBOUNCE = 180

  connect() {
    this.picks = [null, null]
    this.timers = [null, null]
    this.render()
  }

  disconnect() {
    this.timers.forEach((timer) => clearTimeout(timer))
  }

  search(event) {
    const slot = this.inputTargets.indexOf(event.target)
    clearTimeout(this.timers[slot])

    const term = event.target.value.trim()
    if (term.length < 2) return this.showResults(slot, [])

    this.timers[slot] = setTimeout(() => this.fetchFor(slot, term), this.constructor.DEBOUNCE)
  }

  async fetchFor(slot, term) {
    const exclude = this.picks.filter(Boolean).map((pick) => pick.param)
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", term)
    exclude.forEach((param) => url.searchParams.append("exclude[]", param))

    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok) return this.showResults(slot, [])
      this.showResults(slot, await response.json())
    } catch {
      this.showResults(slot, [])
    }
  }

  showResults(slot, players) {
    const list = this.resultsTargets[slot]
    list.innerHTML = ""

    if (players.length === 0) {
      list.hidden = true
      return
    }

    players.forEach((player) => {
      const option = document.createElement("button")
      option.type = "button"
      option.dataset.action = "click->comparison-builder#choose"
      option.dataset.slot = slot
      option.dataset.player = JSON.stringify(player)
      option.className =
        "flex w-full items-baseline gap-2 px-3 py-2 text-left text-sm hover:bg-zinc-50 focus:bg-zinc-50 focus:outline-none"
      option.innerHTML =
        `<span class="font-medium text-zinc-900"></span>` +
        `<span class="text-xs text-zinc-500"></span>`
      option.children[0].textContent = player.full_name
      option.children[1].textContent = [player.team, player.position].filter(Boolean).join(" · ")
      list.appendChild(option)
    })

    list.hidden = false
  }

  choose(event) {
    const slot = Number(event.currentTarget.dataset.slot)
    this.picks[slot] = JSON.parse(event.currentTarget.dataset.player)
    this.inputTargets[slot].value = ""
    this.showResults(slot, [])
    this.render()
  }

  clear(event) {
    const slot = Number(event.currentTarget.dataset.slot)
    this.picks[slot] = null
    this.render()
    this.inputTargets[slot].focus()
  }

  // Enter on a box takes the first name under it, which is what a list of names
  // under a box is for.
  keydown(event) {
    if (event.key !== "Enter") return
    event.preventDefault()

    const slot = this.inputTargets.indexOf(event.target)
    const first = this.resultsTargets[slot].querySelector("button")
    if (first) first.click()
  }

  compare() {
    if (!this.complete) return

    const [left, right] = this.picks
    Turbo.visit(`/compare/${left.param}-vs-${right.param}`)
  }

  get complete() {
    return this.picks.every(Boolean)
  }

  render() {
    this.picks.forEach((pick, slot) => {
      this.chosenTargets[slot].textContent = pick ? pick.full_name : ""
      this.chosenTargets[slot].hidden = !pick
      this.clearTargets[slot].hidden = !pick
      this.inputTargets[slot].hidden = Boolean(pick)
      this.inputTargets[slot].value = ""
    })

    this.submitTarget.disabled = !this.complete
    this.hintTarget.hidden = this.complete
  }
}
