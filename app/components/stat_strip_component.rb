# frozen_string_literal: true

class StatStripComponent < ViewComponent::Base
  def initialize(stats:)
    @stats = stats
  end

  def render? = @stats.present?

  def call
    tag.dl(class: "flex flex-wrap gap-x-10 gap-y-4 rounded-card bg-surface-subtle px-5 py-4") do
      safe_join(@stats.map { |label, value| render(StatComponent.new(label: label, value: value)) })
    end
  end
end
