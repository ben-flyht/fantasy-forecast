# frozen_string_literal: true

class FixtureTableComponent < ViewComponent::Base
  def initialize(title:, rows:, points_label:, empty_message:)
    @title = title
    @rows = rows
    @points_label = points_label
    @empty_message = empty_message
  end

  private

  attr_reader :title, :rows, :points_label, :empty_message

  def date(row)
    row[:gameweek].start_time&.strftime("%-d %b") || "—"
  end

  def points(row)
    return "—" unless row[:points]

    row[:points].is_a?(Integer) ? row[:points] : format("%.1f", row[:points])
  end
end
