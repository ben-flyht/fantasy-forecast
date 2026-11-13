# frozen_string_literal: true

class TeamWatermarkComponent < ViewComponent::Base
  def initialize(team:, lazy: true, **attributes)
    @team = team
    @lazy = lazy
    @attributes = attributes
  end

  def render? = @team&.badge_url.present?

  def call
    safe_join([ layer("opacity-20", silhouette), layer("opacity-[.22]") ])
  end

  private

  def layer(opacity, filter = nil)
    tag.span(class: [ "pointer-events-none", @attributes[:class], opacity ].compact.join(" ")) do
      image_tag @team.badge_url, alt: "", loading: ("lazy" if @lazy),
                class: [ "h-full w-full object-contain", filter ].compact.join(" ")
    end
  end

  def silhouette
    @team.on_light? ? "brightness-0" : "brightness-0 invert"
  end
end
