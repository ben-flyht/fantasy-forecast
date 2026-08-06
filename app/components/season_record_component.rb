# frozen_string_literal: true

# What he has actually done this season, and which way the rates behind it are
# moving.
#
# The five-week form table above says what he scored. This says whether those
# scores were worth the money, how often he blanked, and whether the underlying
# numbers are climbing or falling. All of it is empty until the football starts.
class SeasonRecordComponent < ViewComponent::Base
  def initialize(history:)
    @history = history
  end

  def render?
    history.played? || trends.any?
  end

  private

  attr_reader :history

  def trends
    @trends ||= history.trends
  end

  def totals
    @totals ||= [ total, per_million, best, blanks ].compact
  end

  def total
    return unless history.played?

    [ "Total points", history.total_points.to_s ]
  end

  def per_million
    value = history.points_per_million
    return if value.nil?

    [ "Points per £m", format("%.1f", value) ]
  end

  def best
    week = history.best_week
    return if week.nil?

    [ "Best week", "#{week.value} (GW#{week.gameweek})" ]
  end

  def blanks
    return unless history.played?

    [ "Blanks", "#{history.blanks} of #{history.points.size}" ]
  end

  def latest(trend)
    format("%.2f", trend.latest)
  end
end
