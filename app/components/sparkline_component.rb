# frozen_string_literal: true

# A line of numbers, drawn small.
#
# Plain inline SVG on purpose: the app has no charting library and does not need
# one to draw a dozen points. Nothing here is interactive, so the shape carries
# the meaning and the figure beside it carries the detail.
class SparklineComponent < ViewComponent::Base
  WIDTH = 120
  HEIGHT = 28
  PADDING = 2

  # Two points make a line; one makes a dot nobody can read.
  MINIMUM = 2

  # A rank is better when it is smaller, so its line has to be turned over or it
  # would draw a climb as a fall.
  def initialize(values:, inverted: false)
    @values = Array(values).map(&:to_f)
    @inverted = inverted
  end

  def render?
    @values.size >= MINIMUM && @values.uniq.size > 1
  end

  private

  def points
    @values.each_with_index.map { |value, index| "#{x(index)},#{y(value)}" }.join(" ")
  end

  def x(index)
    PADDING + (index * usable_width / (@values.size - 1).to_f)
  end

  def y(value)
    share = (value - low) / (high - low).to_f
    share = 1 - share unless @inverted

    (PADDING + share * usable_height).round(2)
  end

  def usable_width
    WIDTH - PADDING * 2
  end

  def usable_height
    HEIGHT - PADDING * 2
  end

  def low
    @low ||= @values.min
  end

  def high
    @high ||= @values.max
  end

  # Which way the line finished, so the colour agrees with the story. Rising is
  # good unless the reading is a rank, where the arrow points the other way.
  def improving?
    change = @values.last <=> @values.first
    @inverted ? change.negative? : change.positive?
  end

  def stroke
    improving? ? "#16a34a" : "#dc2626"
  end
end
