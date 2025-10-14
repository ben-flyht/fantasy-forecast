import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "sentinel", "placeholder"]

  connect() {
    // Track current state
    this.isFixed = false
    this.lastStateChange = 0
    this.cooldownPeriod = 300 // 300ms cooldown to prevent rapid toggling

    // Calculate the header height
    const header = document.querySelector('nav')
    if (header) {
      this.headerHeight = header.offsetHeight

      // Store the original container height for the placeholder
      this.containerHeight = this.containerTarget.offsetHeight

      // Find the inner container
      this.innerContainer = this.containerTarget.querySelector('.container')

      // Use scroll event with throttling as backup
      this.handleScroll = this.throttle(() => {
        this.checkPosition()
      }, 50)

      // Observe the sentinel element
      this.observer = new IntersectionObserver(
        ([entry]) => {
          // Only process if enough time has passed since last change
          const now = Date.now()
          if (now - this.lastStateChange < this.cooldownPeriod) {
            return
          }

          const shouldBeFixed = !entry.isIntersecting

          // Only update if state actually needs to change
          if (shouldBeFixed !== this.isFixed) {
            this.lastStateChange = now
            if (shouldBeFixed) {
              this.makeFixed()
            } else {
              this.makeStatic()
            }
          }
        },
        {
          threshold: [0],
          rootMargin: `-${this.headerHeight}px 0px 0px 0px`
        }
      )

      this.observer.observe(this.sentinelTarget)

      // Also listen to scroll as a backup
      window.addEventListener('scroll', this.handleScroll, { passive: true })
    }
  }

  throttle(func, delay) {
    let lastCall = 0
    return function(...args) {
      const now = Date.now()
      if (now - lastCall >= delay) {
        lastCall = now
        func.apply(this, args)
      }
    }
  }

  checkPosition() {
    const sentinelRect = this.sentinelTarget.getBoundingClientRect()
    const shouldBeFixed = sentinelRect.bottom <= this.headerHeight

    const now = Date.now()
    if (now - this.lastStateChange < this.cooldownPeriod) {
      return
    }

    if (shouldBeFixed !== this.isFixed) {
      this.lastStateChange = now
      if (shouldBeFixed) {
        this.makeFixed()
      } else {
        this.makeStatic()
      }
    }
  }

  makeFixed() {
    this.isFixed = true

    // Measure where the inner container is BEFORE changing anything
    const innerRect = this.innerContainer.getBoundingClientRect()
    const targetLeft = innerRect.left

    // Set placeholder height to maintain layout
    this.placeholderTarget.style.height = `${this.containerHeight}px`

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

    // Remove placeholder height
    this.placeholderTarget.style.height = '0'
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.handleScroll) {
      window.removeEventListener('scroll', this.handleScroll)
    }
  }
}
