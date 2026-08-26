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

  # How the three on show stand against the field they were drawn from.
  #
  # "3 of them are forecast to beat him" counted the cards rather than the field,
  # so a player lying a hundred and seventy-sixth was told three defenders were
  # ahead of him under a line that had just said "defenders at £7.0m or less".
  # The count is now of the field, which is what the sentence before it names.
  def verdict
    return if comparison.score.nil?

    better, field = comparison.beaten_by
    return "None of the #{field} is forecast to beat him." if better.zero?

    "#{better} of #{field} #{better == 1 ? 'is' : 'are'} forecast to beat him."
  end
end
