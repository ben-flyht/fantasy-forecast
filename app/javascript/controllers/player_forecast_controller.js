import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async toggleForecast(event) {
    const button = event.currentTarget
    const playerId = button.dataset.playerId
    const position = button.dataset.position
    const isSelected = button.dataset.selected === "true"

    try {
      const response = await fetch('/players/toggle_forecast', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          player_id: playerId
        })
      })

      const data = await response.json()

      if (!response.ok) {
        alert(data.error || 'Failed to update forecast')
        return
      }

      // Update button state
      if (data.selected) {
        button.classList.remove('text-gray-300', 'hover:text-yellow-300')
        button.classList.add('text-yellow-400', 'drop-shadow-lg', 'filter')
        button.style.textShadow = '0 0 10px rgba(250, 204, 21, 0.8)'
        button.dataset.selected = "true"
      } else {
        button.classList.remove('text-yellow-400', 'drop-shadow-lg', 'filter')
        button.classList.add('text-gray-300', 'hover:text-yellow-300')
        button.style.textShadow = ''
        button.dataset.selected = "false"
      }

      // Update row highlighting
      const row = document.querySelector(`tr[data-player-row="${playerId}"]`)
      if (row) {
        if (data.selected) {
          row.className = 'bg-yellow-100 border-l-4 border-yellow-400'
        } else {
          // Reset to default (no highlighting)
          row.className = ''
        }
      }

      // Update position counters
      this.updatePositionCounters(data.forecast_counts)

    } catch (error) {
      console.error('Error toggling forecast:', error)
      alert('Failed to update forecast')
    }
  }

  updatePositionCounters(forecastCounts) {
    // Update the position filter buttons with new counts
    const positionConfig = {
      'goalkeeper': 5,
      'defender': 10,
      'midfielder': 10,
      'forward': 5
    }

    Object.keys(positionConfig).forEach(position => {
      const count = forecastCounts[position] || 0
      const maxSlots = positionConfig[position]

      // Find the position button and update its counter
      const positionButtons = document.querySelectorAll('input[name="position"]')
      positionButtons.forEach(radio => {
        if (radio.value === position) {
          const label = radio.closest('label')
          const counterSpan = label.querySelector('span')
          if (counterSpan) {
            counterSpan.textContent = `(${count}/${maxSlots})`
            // Add green color if at max
            if (count === maxSlots) {
              counterSpan.classList.add('text-green-400')
            } else {
              counterSpan.classList.remove('text-green-400')
            }
          }
        }
      })
    })
  }
}
