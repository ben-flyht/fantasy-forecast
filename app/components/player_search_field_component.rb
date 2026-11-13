# frozen_string_literal: true

class PlayerSearchFieldComponent < ViewComponent::Base
  SIDES = [ "the first", "the second" ].freeze

  def initialize(side:)
    @side = side
  end

  private

  attr_reader :side

  def label = "Add a player to #{SIDES.fetch(side)} side"

  def results_id = "comparison-results-#{side}"
end
