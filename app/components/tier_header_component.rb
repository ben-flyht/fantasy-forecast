# frozen_string_literal: true

class TierHeaderComponent < ViewComponent::Base
  def initialize(tier:)
    @tier = tier
    @tier_info = TierCalculator::TIERS[tier]
  end

  def symbol
    @tier_info[:symbol]
  end

  def name
    @tier_info[:name]
  end

  def description
    @tier_info[:description]
  end

  def background_class
    "bg-white"
  end
end
