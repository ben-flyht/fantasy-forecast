# frozen_string_literal: true

class TierHeaderComponent < ViewComponent::Base
  def initialize(tier:, player_count:)
    @tier = tier
    @tier_info = TierCalculator::TIERS[tier]
    @player_count = player_count
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
    {
      1 => "bg-amber-100 border-amber-300",
      2 => "bg-sky-50 border-sky-200",
      3 => "bg-gray-100 border-gray-200",
      4 => "bg-slate-200 border-slate-300",
      5 => "bg-blue-50 border-blue-200"
    }[@tier] || "bg-gray-50"
  end
end
