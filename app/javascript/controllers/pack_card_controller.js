import { Controller } from "@hotwired/stimulus"

const TILT = 16
const RESTING = ["--ry", "--rx", "--mx", "--my", "--tx", "--ty", "--glare"]

export default class extends Controller {
  connect() {
    this.still = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  tilt(event) {
    if (this.still) return
    if (event.pointerType === "touch" && !this.pressed) return

    const box = this.element.getBoundingClientRect()
    const x = Math.min(Math.max((event.clientX - box.left) / box.width, 0), 1)
    const y = Math.min(Math.max((event.clientY - box.top) / box.height, 0), 1)

    this.element.classList.add("is-tilting")
    this.set({
      "--ry": `${(x - 0.5) * TILT}deg`,
      "--rx": `${(0.5 - y) * TILT}deg`,
      "--mx": `${x * 100}%`,
      "--my": `${y * 100}%`,
      "--tx": `${x}`,
      "--ty": `${y}`,
      "--glare": "1"
    })
  }

  press(event) {
    this.pressed = true
    this.element.classList.add("is-pressed")
    this.tilt(event)
  }

  release() {
    this.pressed = false
    this.element.classList.remove("is-pressed")
  }

  rest() {
    this.release()
    this.element.classList.remove("is-tilting")
    RESTING.forEach((name) => this.element.style.removeProperty(name))
  }

  set(properties) {
    Object.entries(properties).forEach(([name, value]) => this.element.style.setProperty(name, value))
  }
}
