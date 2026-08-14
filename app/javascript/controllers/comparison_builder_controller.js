import { Controller } from "@hotwired/stimulus"

// The two sides, laid out the same whether you are building an argument or reading
// one. A side is its players and a box at the foot of it you can always type into;
// a player joins as a card and leaves by the cross on it.
//
// The moment both sides hold a player there is a page for them, so we go to it. On the
// hub that turns a first pick on each side into the comparison; on the comparison it
// turns every add, remove or swap into the page for the sides you have now. Take the
// last player off a side and it empties to its box, waiting for whoever replaces him,
// because an empty side is not yet a question. The chips in the DOM are the state, so
// nothing is held in step with them.
export default class extends Controller {
  static targets = ["side", "chips", "chip", "input", "results", "hint"]
  static values = { url: String }

  // How long to wait after the last keystroke before asking. Short enough to feel
  // immediate, long enough that typing a name is one request rather than eight.
  static DEBOUNCE = 180

  connect() {
    this.timers = new Map()
    this.active = new Map()
    this.render()
  }

  disconnect() {
    this.timers.forEach((timer) => clearTimeout(timer))
  }

  search(event) {
    const side = this.sideOf(event.target)
    clearTimeout(this.timers.get(side))

    const term = event.target.value.trim()
    if (term.length < 2) return this.showResults(side, [])

    this.timers.set(side, setTimeout(() => this.fetchFor(side, term), this.constructor.DEBOUNCE))
  }

  async fetchFor(side, term) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", term)
    this.chosenParams.forEach((param) => url.searchParams.append("exclude[]", param))

    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok) return this.showResults(side, [])
      this.showResults(side, await response.json())
    } catch {
      this.showResults(side, [])
    }
  }

  showResults(side, players) {
    const list = this.resultsFor(side)
    list.innerHTML = ""

    const input = this.inputFor(side)

    if (players.length === 0) {
      list.hidden = true
      this.active.delete(side)
      input.setAttribute("aria-expanded", "false")
      input.removeAttribute("aria-activedescendant")
      return
    }

    players.forEach((player, index) => {
      const option = document.createElement("button")
      option.type = "button"
      option.role = "option"
      option.id = `comparison-option-${side}-${index}`
      option.dataset.action = "click->comparison-builder#choose"
      option.dataset.side = side
      option.dataset.player = JSON.stringify(player)
      option.className =
        "flex w-full items-baseline gap-2 px-3 py-2 text-left text-sm hover:bg-zinc-50 focus:bg-zinc-50 focus:outline-none aria-selected:bg-zinc-100"
      option.innerHTML =
        `<span class="font-medium text-zinc-900"></span>` +
        `<span class="text-xs text-zinc-500"></span>`
      option.children[0].textContent = player.full_name
      option.children[1].textContent = [player.team, player.position].filter(Boolean).join(" · ")
      list.appendChild(option)
    })

    list.hidden = false
    input.setAttribute("aria-expanded", "true")
    this.active.set(side, 0)
    this.paintHighlight(side)
  }

  paintHighlight(side) {
    const options = this.optionsFor(side)
    const index = this.active.get(side)
    options.forEach((option, position) => {
      const on = position === index
      option.setAttribute("aria-selected", on)
      if (on) {
        option.scrollIntoView({ block: "nearest" })
        this.inputFor(side).setAttribute("aria-activedescendant", option.id)
      }
    })
  }

  optionsFor(side) {
    return Array.from(this.resultsFor(side).querySelectorAll("button"))
  }

  choose(event) {
    const side = this.sideOf(event.currentTarget)
    const player = JSON.parse(event.currentTarget.dataset.player)

    const sides = this.sidesParams()
    if (!sides.flat().includes(player.param)) sides[side].push(player.param)

    const input = this.inputFor(side)
    input.value = ""
    this.showResults(side, [])

    // Both sides filled: there is a page for them, and it is drawn with the real
    // cards. Otherwise keep the pick here as a chip, and let the address keep up so a
    // half-built comparison can be shared or reloaded where it was left.
    if (this.bothFilled(sides)) return this.visit(sides)

    this.chipsFor(side)?.appendChild(this.chip(side, player))
    this.render()
    this.reflect(sides)
    input.focus()
  }

  remove(event) {
    const chip = event.currentTarget.closest("[data-comparison-builder-target=chip]")
    const side = this.sideOf(chip)

    const sides = this.sidesParams()
    sides[side] = sides[side].filter((param) => param !== chip.dataset.param)

    // Still a player on each side: there is a smaller comparison, so go to it — without
    // taking the card out first, so the page Turbo leaves behind still shows what it
    // showed. Take the last one off a side and it empties to its box instead, waiting
    // for whoever replaces him, because an empty side is not a page.
    if (this.bothFilled(sides)) return this.visit(sides)

    chip.remove()
    this.clearPick()
    this.render()
    this.reflect(sides)
    this.inputFor(side).focus()
  }

  // Once a side is being rebuilt there is no pick to show, so the badge and the ring
  // come off until a whole comparison is settled again and the next page draws them.
  clearPick() {
    this.element.querySelectorAll("[data-pick-badge]").forEach((badge) => badge.remove())
    this.element.querySelectorAll("[data-pick-ring]").forEach((ring) =>
      ring.classList.replace("ring-zinc-900", "ring-transparent"))
    this.element.querySelectorAll("[data-comparison-card]").forEach((card) => (card.dataset.pick = "false"))
  }

  // Walk the names under the box with the arrow keys, take the highlighted one with
  // Enter, and dismiss the list with Escape. The first name is highlighted the moment
  // the list opens, so Enter still takes it without a keystroke in between.
  keydown(event) {
    const side = this.sideOf(event.target)
    const options = this.optionsFor(side)
    if (options.length === 0) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.active.set(side, Math.min((this.active.get(side) ?? -1) + 1, options.length - 1))
        this.paintHighlight(side)
        break
      case "ArrowUp":
        event.preventDefault()
        this.active.set(side, Math.max((this.active.get(side) ?? 0) - 1, 0))
        this.paintHighlight(side)
        break
      case "Enter": {
        event.preventDefault()
        const chosen = options[this.active.get(side) ?? 0]
        if (chosen) chosen.click()
        break
      }
      case "Escape":
        this.showResults(side, [])
        break
    }
  }

  visit(sides) {
    Turbo.visit(`/compare/${this.address(sides)}`, { action: "advance" })
  }

  // Keep the address in step with a half-built comparison, without loading anything:
  // the sides so far are in the bar, so it can be shared or reloaded and picked up.
  reflect(sides) {
    const url = sides.flat().length ? `/compare/${this.address(sides)}` : "/compare"
    history.replaceState(history.state, "", url)
  }

  address(sides) {
    return sides.map((players) => players.join("-and-")).join("-vs-")
  }

  bothFilled(sides) {
    return sides[0].length > 0 && sides[1].length > 0
  }

  sidesParams() {
    return [ this.paramsOn(0), this.paramsOn(1) ]
  }

  paramsOn(side) {
    return this.chipTargets
      .filter((chip) => this.sideOf(chip) === side)
      .map((chip) => chip.dataset.param)
  }

  get chosenParams() {
    return this.chipTargets.map((chip) => chip.dataset.param)
  }

  render() {
    if (this.hasHintTarget) this.hintTarget.hidden = this.bothFilled(this.sidesParams())
  }

  // A card-shaped tile for a player picked while a side is still being built, before
  // there is a page with his real card on it.
  chip(side, player) {
    const chip = document.createElement("div")
    chip.className = "relative rounded-xl border border-zinc-200 bg-white px-3 py-2 pr-8"
    chip.dataset.comparisonBuilderTarget = "chip"
    chip.dataset.side = side
    chip.dataset.param = player.param

    const name = document.createElement("p")
    name.className = "text-sm font-medium text-zinc-900"
    name.textContent = player.full_name

    const meta = document.createElement("p")
    meta.className = "text-xs text-zinc-500"
    meta.textContent = [player.team, player.position].filter(Boolean).join(" · ")

    chip.appendChild(name)
    chip.appendChild(meta)
    chip.appendChild(this.removeButton(player.full_name))
    return chip
  }

  removeButton(name) {
    const remove = document.createElement("button")
    remove.type = "button"
    remove.dataset.action = "comparison-builder#remove"
    remove.setAttribute("aria-label", `Remove ${name}`)
    remove.className =
      "absolute right-2 top-2 rounded p-0.5 text-zinc-400 hover:text-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-900/20"
    remove.innerHTML =
      `<svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">` +
      `<path stroke-linecap="round" d="M6 6l12 12M18 6L6 18"/></svg>`
    return remove
  }

  chipsFor(side) {
    return this.chipsTargets[side]
  }

  inputFor(side) {
    return this.inputTargets.find((input) => this.sideOf(input) === side)
  }

  resultsFor(side) {
    return this.resultsTargets.find((results) => this.sideOf(results) === side)
  }

  sideOf(element) {
    return Number(element.dataset.side)
  }
}
