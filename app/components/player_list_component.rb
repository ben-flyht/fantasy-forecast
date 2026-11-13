# frozen_string_literal: true

class PlayerListComponent < ViewComponent::Base
  def initialize(entries:, leading_label: "Rank")
    @entries = entries
    @leading_label = leading_label
  end

  def render? = entries.present?

  private

  attr_reader :entries, :leading_label
end
