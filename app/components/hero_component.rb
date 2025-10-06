# frozen_string_literal: true

class HeroComponent < ViewComponent::Base
  renders_one :title
  renders_one :subtitle

  def initialize(centered: true)
    @centered = centered
  end
end
