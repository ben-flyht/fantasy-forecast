module PlayersHelper
  def player_meta_title(player, forecast)
    return "#{player.full_name} FPL Stats and Forecast | Fantasy Forecast" unless forecast

    horizon = Horizon.find(forecast[:horizon]).short_label(gameweek: forecast[:gameweek])
    "#{player.full_name} FPL Prediction #{horizon} | Fantasy Forecast"
  end

  def player_meta_description(player, forecast, stats)
    intro = player_meta_intro(player, stats)
    return "#{intro}: price, ownership, fixtures and form for your Fantasy Premier League decisions." unless forecast

    "#{intro}: #{player_meta_forecast(forecast)}. Fixtures, form and the FPL alternatives worth comparing."
  end

  private

  def player_meta_intro(player, stats)
    who = [ player.team&.name, player.position ].compact.join(" ")
    "#{player.full_name} (#{[ who, *player_facts(stats) ].join(', ')})"
  end

  def player_meta_forecast(forecast)
    horizon = Horizon.find(forecast[:horizon]).label(gameweek: forecast[:gameweek])
    points = "#{format('%.1f', forecast[:score].to_f)} expected points for #{horizon}"
    forecast[:grade] == TierCalculator::UNGRADED ? points : "#{points}, graded #{forecast[:grade]}"
  end
end
