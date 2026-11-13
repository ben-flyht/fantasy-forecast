# frozen_string_literal: true

class FormStripComponent < ViewComponent::Base
  FULL_SCALE = 10
  SHORTEST = 0.06

  def initialize(title:, rows:, empty_message:)
    @title = title
    @rows = rows.sort_by { |row| row[:gameweek].fpl_id }
    @empty_message = empty_message
  end

  private

  attr_reader :title, :rows, :empty_message

  def scale
    @scale ||= [ rows.filter_map { |row| row[:points] }.max.to_i, FULL_SCALE ].max
  end

  def height(row)
    "calc((100% - 1.5rem) * #{[ (row[:points].to_f / scale).round(2), SHORTEST ].max})"
  end

  def blank?(row)
    row[:points].to_i <= PlayerHistory::BLANK
  end

  def opponent(row)
    row[:opponent]&.short_name || row[:opponent]&.name
  end
end
