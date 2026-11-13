# frozen_string_literal: true

class StatComponent < ViewComponent::Base
  SIZES = {
    md: "mt-1 text-figure",
    xl: "mt-1.5 text-display"
  }.freeze

  def initialize(label:, value:, size: :md)
    @label = label
    @value = value
    @size = size
  end

  private

  attr_reader :label, :value

  def value_classes
    "#{SIZES.fetch(@size)} tabular-nums text-ink"
  end
end
