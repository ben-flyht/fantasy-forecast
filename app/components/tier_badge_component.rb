# frozen_string_literal: true

class TierBadgeComponent < ViewComponent::Base
  def initialize(tier:, show_name: false)
    @tier = tier
    @tier_info = TierCalculator::TIERS[tier]
    @show_name = show_name
  end

  def symbol
    @tier_info[:symbol]
  end

  def name
    @tier_info[:name]
  end

  def show_name?
    @show_name
  end
end
