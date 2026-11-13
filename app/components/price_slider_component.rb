# frozen_string_literal: true

class PriceSliderComponent < ViewComponent::Base
  def initialize(filter:)
    @filter = filter
  end

  def render? = filter.present?

  private

  attr_reader :filter

  def range_options(target, label)
    { min: filter[:floor], max: filter[:ceil], step: filter[:step], "aria-label": label,
      data: { "price-slider-target": target, action: "input->price-slider#onInput change->price-slider#commit" } }
  end

  def price(millions)
    helpers.player_price(millions * ApplicationHelper::TENTHS_PER_MILLION)
  end
end
