# frozen_string_literal: true

class StatComparisonComponent < ViewComponent::Base
  SIDES = %i[left right].freeze

  def initialize(rows:)
    @rows = rows
  end

  def render? = rows.present?

  private

  attr_reader :rows

  def value_classes(row, side)
    row.leader == side ? "font-bold text-ink" : "text-muted"
  end

  def bar(row, side)
    return unless row.shares

    tag.span(class: "block h-1.5 rounded-full #{row.leader == side ? 'bg-ink' : 'bg-line-strong'}",
             style: "width: #{(row.shares[SIDES.index(side)] * 100).round}%")
  end
end
