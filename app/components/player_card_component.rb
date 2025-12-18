# frozen_string_literal: true

class PlayerCardComponent < ViewComponent::Base
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

  private

  def bot_forecast
    @bot_forecast ||= begin
      bot = User.bot rescue nil
      return nil unless bot

      bot.forecasts.find_by(player: @player, gameweek: @gameweek)
    end
  end
end
