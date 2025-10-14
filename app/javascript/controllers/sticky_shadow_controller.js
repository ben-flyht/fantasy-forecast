import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "sentinel", "placeholder"]

  connect() {
    // Track current state to prevent unnecessary updates
    this.isFixed = false
    this.debounceTimer = null

    // Calculate the header height
    const header = document.querySelector('nav')
    if (header) {
      this.headerHeight = header.offsetHeight

      // Store the original container height for the placeholder
      this.containerHeight = this.containerTarget.offsetHeight

      // Find the inner container
      this.innerContainer = this.containerTarget.querySelector('.container')

      // Observe the sentinel element - when it's not visible, make the element fixed
      // Use a larger threshold and rootMargin to prevent rapid toggling
      this.observer = new IntersectionObserver(
        ([e]) => {
          // Debounce to prevent rapid state changes
          clearTimeout(this.debounceTimer)
          this.debounceTimer = setTimeout(() => {
            const shouldBeFixed = !e.isIntersecting

            // Only update if state actually changed
            if (shouldBeFixed !== this.isFixed) {
              if (shouldBeFixed) {
                this.makeFixed()
              } else {
                this.makeStatic()
              }
            }
          }, 10)
        },
        {
          threshold: [0],
          rootMargin: `-${this.headerHeight + 5}px 0px 0px 0px` // Add 5px buffer
        }
      )

      this.observer.observe(this.sentinelTarget)
    }
  }

  makeFixed() {
    this.isFixed = true

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
    this.isFixed = false

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
    // Clear any pending debounce timer
    clearTimeout(this.debounceTimer)

    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
