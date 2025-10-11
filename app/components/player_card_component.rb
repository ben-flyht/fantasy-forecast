# frozen_string_literal: true

class PlayerCardComponent < ViewComponent::Base
  STATUS_BADGE_CLASSES = {
    "red" => "border border-red-200 bg-red-50 text-red-800",
    "orange" => "border border-orange-200 bg-orange-50 text-orange-800",
    "yellow" => "border border-yellow-200 bg-yellow-50 text-yellow-800",
    "green" => "border border-green-200 bg-green-50 text-green-800"
  }.freeze

  def initialize(player: nil, show_position: false, selection_url: nil)
    @player = player
    @show_position = show_position
    @selection_url = selection_url
  end

  def status_badge_class
    STATUS_BADGE_CLASSES[status_color]
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
      doubtful_status_text
    when "n"
      "Ineligible"
    end
  end

  def doubtful_status_text
    case chance_of_playing
    when 0..74
      "Doubtful"
    else
      "Slight Doubt"
    end
  end

  def show_status_info?
    @player && chance_of_playing.present? && chance_of_playing < 100
  end

  private

  def chance_of_playing
    @chance_of_playing ||= @player&.chance_of_playing
  end

  def status_color
    case chance_of_playing
    when 0..25 then "red"
    when 26..50 then "orange"
    when 51..75 then "yellow"
    else "green"
    end
  end
end
