import { Controller } from "@hotwired/stimulus"

// Two sides, a box or three on each, a list of names under whichever one you are
// typing in, and a button that takes you to the argument.
//
// A side is one player, or the players you would buy in one move: a manager with two
// free transfers is choosing between two pairs rather than two players. Only the first
// box of each side is offered, and the next one appears when the one before it is
// filled, so the common question still looks like two boxes and a button.
//
// The address is assembled here from both sides in whatever order they were picked:
// /compare answers the same question every way round and redirects to its own
// spelling of it.
export default class extends Controller {
  static targets = ["slot", "input", "results", "chosen", "clear", "submit", "hint", "add"]
  static values = { url: String }

  // How long to wait after the last keystroke before asking. Short enough to feel
  // immediate, long enough that typing a name is one request rather than eight.
  static DEBOUNCE = 180

  connect() {
    // Keyed by the box itself rather than by a number, so nothing has to agree with
    // anything else about which box is which.
    this.picks = new Map()
    this.timers = new Map()
    this.render()
  }

  disconnect() {
    this.timers.forEach((timer) => clearTimeout(timer))
  }

  search(event) {
    const slot = this.slotOf(event.target)
    clearTimeout(this.timers.get(slot))

    const term = event.target.value.trim()
    if (term.length < 2) return this.showResults(slot, [])

    this.timers.set(slot, setTimeout(() => this.fetchFor(slot, term), this.constructor.DEBOUNCE))
  }

  async fetchFor(slot, term) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", term)
    this.chosen.forEach((player) => url.searchParams.append("exclude[]", player.param))

    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok) return this.showResults(slot, [])
      this.showResults(slot, await response.json())
    } catch {
      this.showResults(slot, [])
    }
  }

  showResults(slot, players) {
    const list = this.within(slot, "results")
    list.innerHTML = ""

    if (players.length === 0) {
      list.hidden = true
      return
    }

    players.forEach((player) => {
      const option = document.createElement("button")
      option.type = "button"
      option.dataset.action = "click->comparison-builder#choose"
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
    const slot = this.slotOf(event.currentTarget)
    this.picks.set(slot, JSON.parse(event.currentTarget.dataset.player))
    this.showResults(slot, [])
    this.render()
  }

  clear(event) {
    const slot = this.slotOf(event.currentTarget)
    this.picks.delete(slot)
    this.render()
    this.within(slot, "input").focus()
  }

  // The next box on this side, which is only offered once the ones before it are full.
  add(event) {
    const next = this.slotsFor(event.currentTarget.dataset.side).find((slot) => slot.hidden)
    if (!next) return

    next.hidden = false
    this.render()
    this.within(next, "input").focus()
  }

  // Enter on a box takes the first name under it, which is what a list of names
  // under a box is for.
  keydown(event) {
    if (event.key !== "Enter") return
    event.preventDefault()

    const first = this.within(this.slotOf(event.target), "results").querySelector("button")
    if (first) first.click()
  }

  compare() {
    if (!this.complete) return

    Turbo.visit(`/compare/${this.slugFor(0)}-vs-${this.slugFor(1)}`)
  }

  slugFor(side) {
    return this.playersOn(side).map((player) => player.param).join("-and-")
  }

  playersOn(side) {
    return this.slotsFor(side).map((slot) => this.picks.get(slot)).filter(Boolean)
  }

  slotsFor(side) {
    return this.slotTargets.filter((slot) => slot.dataset.side === String(side))
  }

  slotOf(element) {
    return element.closest("[data-comparison-builder-target=slot]")
  }

  within(slot, target) {
    return slot.querySelector(`[data-comparison-builder-target=${target}]`)
  }

  get chosen() {
    return [...this.picks.values()]
  }

  get complete() {
    return this.playersOn(0).length > 0 && this.playersOn(1).length > 0
  }

  render() {
    this.slotTargets.forEach((slot) => {
      const pick = this.picks.get(slot)
      const input = this.within(slot, "input")

      this.within(slot, "chosen").textContent = pick ? pick.full_name : ""
      this.within(slot, "chosen").hidden = !pick
      this.within(slot, "clear").hidden = !pick
      input.hidden = Boolean(pick)
      input.value = ""
    })

    // Another box is offered where there is one left and every box already open on
    // that side has somebody in it.
    this.addTargets.forEach((button) => {
      const slots = this.slotsFor(button.dataset.side)
      const open = slots.filter((slot) => !slot.hidden)
      button.hidden = open.length === slots.length || !open.every((slot) => this.picks.has(slot))
    })

    this.submitTarget.disabled = !this.complete
    this.hintTarget.hidden = this.complete
  }
}
