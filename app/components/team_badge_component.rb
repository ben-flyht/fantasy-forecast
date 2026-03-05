# frozen_string_literal: true

class TeamBadgeComponent < ViewComponent::Base
  def initialize(team:, size: 20)
    @team = team
    @size = size
  end

  def render?
    @team&.badge_url.present?
  end

  def call
    image_tag @team.badge_url, alt: "", style: "height:#{@size}px;width:auto;max-width:#{@size * 2}px"
  end
end
