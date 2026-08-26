# frozen_string_literal: true

# What he did last season, at the foot of the page.
#
# In August this is the only real evidence there is, and the page had none of it:
# "This season" above it was one row of one gameweek. The forecast has read last
# season all along, blended against this one by how much of this one there is, so
# a reader asked to trust a number in the second week was being shown almost none
# of what produced it.
#
# Totals across the top, because a season's football is a total. Rates underneath,
# because a rate is what carries forward and the totals do not. Anything at nought
# is left out rather than printed: a forward has no saves and a keeper takes no
# shots, and a column of noughts is not a record.
class LastSeasonComponent < ViewComponent::Base
  MINUTES_IN_A_MATCH = 90.0

  # Every figure this reads, so the controller can load exactly these.
  TYPES = %w[
    last_season_points last_season_minutes last_season_starts last_season_assists
    last_season_bonus last_season_goals_per_90 last_season_expected_goals_per_90
    last_season_expected_assists_per_90 last_season_clean_sheets_per_90
    last_season_saves_per_90 last_season_defensive_contribution_per_90
  ].freeze

  # The rates worth reading, in the order a manager weighs them, and who FPL pays
  # for each. A rate nobody is paid for is not a record of anything: a forward's
  # side keeps clean sheets and he is paid nothing for them, and a goalkeeper is
  # paid nothing for winning the ball back.
  RATES = {
    "last_season_goals_per_90" => [ "Goals, per 90", :anybody ],
    "last_season_expected_goals_per_90" => [ "Expected goals, per 90", :anybody ],
    "last_season_expected_assists_per_90" => [ "Expected assists, per 90", :anybody ],
    "last_season_clean_sheets_per_90" => [ "Clean sheets, per 90", :paid_for_sheets ],
    "last_season_saves_per_90" => [ "Saves, per 90", :keeper ],
    "last_season_defensive_contribution_per_90" => [ "Defensive contributions, per 90", :paid_for_defending ]
  }.freeze

  def initialize(stats:, position:)
    @stats = stats || {}
    @position = position
  end

  # A player with no last season in this league has nothing to show, and a
  # promoted side is full of them. Minutes are the test: without them nothing
  # else here means anything.
  def render?
    minutes.positive?
  end

  private

  attr_reader :stats, :position

  def minutes
    @minutes ||= value("last_season_minutes")
  end

  def totals
    @totals ||= [ points, starts, played, per_90, assists, bonus ].compact
  end

  def points
    [ "Points", value("last_season_points").round.to_s ]
  end

  # Only once FPL's starts have been stored for a past season. Until then the
  # line is absent rather than nought, because nought starts is a claim.
  def starts
    figure = value("last_season_starts")
    return if figure.zero?

    [ "Starts", figure.round.to_s ]
  end

  def played
    [ "Minutes", helpers.number_with_delimiter(minutes.round) ]
  end

  # What a season's points came to per 90 on the pitch, which is the figure that
  # compares with anybody else's and the one the totals cannot give on their own.
  def per_90
    [ "Points per 90", format("%.1f", value("last_season_points") / (minutes / MINUTES_IN_A_MATCH)) ]
  end

  def assists
    figure = value("last_season_assists")
    return if figure.zero?

    [ "Assists", figure.round.to_s ]
  end

  def bonus
    figure = value("last_season_bonus")
    return if figure.zero?

    [ "Bonus", figure.round.to_s ]
  end

  def rates
    @rates ||= RATES.filter_map do |type, (label, paid)|
      figure = value(type)
      [ label, format("%.2f", figure) ] if figure.positive? && paid?(paid)
    end
  end

  # Whether FPL pays this position for that, read from the scoring table the
  # forecast itself prices from rather than from a second list that can drift.
  def paid?(rule)
    case rule
    when :keeper then position == ExpectedPoints::GOALKEEPER
    when :paid_for_sheets then ExpectedPoints::CLEAN_SHEET.fetch(position, 0).positive?
    when :paid_for_defending then ExpectedPoints::DEFENSIVE_ACTIONS.key?(position)
    else true
    end
  end

  def value(type)
    stats[type].to_f
  end
end
