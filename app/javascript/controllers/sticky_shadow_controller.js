import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "sentinel", "placeholder"]

  connect() {
    // Calculate the header height
    const header = document.querySelector('nav')
    if (header) {
      this.headerHeight = header.offsetHeight

      // Store the original container height for the placeholder
      this.containerHeight = this.containerTarget.offsetHeight

      // Find the inner container
      this.innerContainer = this.containerTarget.querySelector('.container')

      // Observe the sentinel element - when it's not visible, make the element fixed
      this.observer = new IntersectionObserver(
        ([e]) => {
          if (e.isIntersecting) {
            // Sentinel is visible, element is in normal flow
            this.makeStatic()
          } else {
            // Sentinel is hidden, element should be fixed
            this.makeFixed()
          }
        },
        { threshold: [0], rootMargin: `-${this.headerHeight}px 0px 0px 0px` }
      )

      this.observer.observe(this.sentinelTarget)
    }
  }

  makeFixed() {
    // Measure where the inner container is BEFORE changing anything
    const innerRect = this.innerContainer.getBoundingClientRect()
    const targetLeft = innerRect.left

    this.containerTarget.style.position = 'fixed'
    this.containerTarget.style.top = `${this.headerHeight}px`
    this.containerTarget.style.left = '0'
    this.containerTarget.style.right = '0'
    this.containerTarget.style.width = '100%'
    this.containerTarget.style.marginLeft = '0'
    this.containerTarget.style.marginRight = '0'
    this.containerTarget.classList.add("shadow-md")

    // Override the inner container's auto margins to keep it in place
    this.innerContainer.style.marginLeft = `${targetLeft}px`
    this.innerContainer.style.marginRight = 'auto'

    // Show placeholder to prevent layout shift
    this.placeholderTarget.style.display = 'block'
    this.placeholderTarget.style.height = `${this.containerHeight}px`
  }

  makeStatic() {
    this.containerTarget.style.position = 'static'
    this.containerTarget.style.top = ''
    this.containerTarget.style.left = ''
    this.containerTarget.style.right = ''
    this.containerTarget.style.width = ''
    this.containerTarget.style.marginLeft = ''
    this.containerTarget.style.marginRight = ''
    this.containerTarget.classList.remove("shadow-md")

    // Reset inner container margins to use auto centering
    this.innerContainer.style.marginLeft = ''
    this.innerContainer.style.marginRight = ''

    // Hide placeholder
    this.placeholderTarget.style.display = 'none'
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
