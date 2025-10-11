# frozen_string_literal: true

class PlayerCardComponent < ViewComponent::Base
  def initialize(player: nil, show_position: false, selection_url: nil)
    @player = player
    @show_position = show_position
    @selection_url = selection_url
  end

  def status_badge_class
    color = status_color
    "border border-#{color}-200 bg-#{color}-50 text-#{color}-800"
  end

  def status_text
    case @player&.status
    when "a"
      "Available"
    when "i"
      "Injured"
    when "s"
      "Suspended"
    when "u"
      "Unavailable"
    when "d"
      "Doubtful"
    when "n"
      "Ineligible"
    end
  end

  def show_status_info?
    @player && @player.chance_of_playing.present? && @player.chance_of_playing < 100
  end

  private

  def status_color
    chance = @player&.chance_of_playing
    case chance
    when 0..25 then "red"
    when 26..50 then "orange"
    when 51..75 then "yellow"
    else "green"
    end
  end
end
