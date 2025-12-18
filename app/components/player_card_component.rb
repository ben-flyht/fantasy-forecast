# frozen_string_literal: true

class PlayerCardComponent < ViewComponent::Base
  STATUS_BADGE_CLASSES = {
    "red" => "border border-red-200 bg-red-50 text-red-800",
    "orange" => "border border-orange-200 bg-orange-50 text-orange-800",
    "yellow" => "border border-yellow-200 bg-yellow-50 text-yellow-800",
    "green" => "border border-green-200 bg-green-50 text-green-800"
  }.freeze

  STATUS_TEXTS = {
    "a" => "Available", "i" => "Injured", "s" => "Suspended",
    "u" => "Unavailable", "n" => "Ineligible"
  }.freeze

  def initialize(player: nil, show_position: false, selection_url: nil, show_ff_rank: false, gameweek: nil)
    @player = player
    @show_position = show_position
    @selection_url = selection_url
    @show_ff_rank = show_ff_rank
    @gameweek = gameweek
  end

  def ff_rank
    return nil unless @show_ff_rank && @player && @gameweek

    @ff_rank ||= bot_forecast&.rank
  end

  def show_ff_rank?
    @show_ff_rank && ff_rank.present?
  end

  def status_badge_class
    STATUS_BADGE_CLASSES[status_color]
  end

  def status_text
    return doubtful_status_text if @player&.status == "d"

    STATUS_TEXTS[@player&.status]
  end

  def show_status_info?
    @player && chance_of_playing.present? && chance_of_playing < 100
  end

  private

  def doubtful_status_text
    chance_of_playing <= 74 ? "Doubtful" : "Slight Doubt"
  end

  def bot_forecast
    @bot_forecast ||= begin
      bot = User.bot rescue nil
      return nil unless bot

      bot.forecasts.find_by(player: @player, gameweek: @gameweek)
    end
  end

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
