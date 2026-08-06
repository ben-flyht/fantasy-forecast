# frozen_string_literal: true

# The three players this money would buy instead, shown as the cards they are
# shown as everywhere else on the site.
#
# It sits inside the forecast panel rather than below it because it is part of
# the same thought: here is what he is worth, and here is what else you could
# have for the money. A reader deciding a transfer should not have to scroll to
# find the other half of the question.
class AlternativesComponent < ViewComponent::Base
  def initialize(comparison:, player:, horizon:)
    @comparison = comparison
    @player = player
    @horizon = horizon
  end

  def render?
    alternatives.any?
  end

  private

  attr_reader :comparison, :player, :horizon

  def alternatives
    comparison.alternatives
  end

  # The heading says which of the two answers the reader is getting, because
  # "nobody affordable beats him" is as useful as a list of upgrades and should
  # not be left to be inferred from the numbers.
  def heading
    comparison.upgrade? ? "Better for the money" : "The best of what else is affordable"
  end

  def subtitle
    "#{player.position.capitalize}s at #{helpers.player_price(comparison.ceiling)} or less, best forecast first."
  end

  def verdict
    return if comparison.score.nil?
    return "None of them is forecast to beat him." unless comparison.upgrade?

    "#{beating.size} of them #{beating.one? ? 'is' : 'are'} forecast to beat him."
  end

  def beating
    alternatives.select { |entry| entry.score.to_f > comparison.score }
  end
end
