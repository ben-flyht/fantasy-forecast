# frozen_string_literal: true

class PlayerCardComponent < ViewComponent::Base
  def initialize(player: nil, show_position: false, selection_url: nil)
    @player = player
    @show_position = show_position
    @selection_url = selection_url
  end

  def status_badge_class
    chance = @player&.chance_of_playing

    if chance <= 25
      "bg-red-100 text-red-800"
    elsif chance <= 50
      "bg-orange-100 text-orange-800"
    elsif chance <= 75
      "bg-yellow-100 text-yellow-800"
    else
      "bg-green-100 text-green-800"
    end
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
end
