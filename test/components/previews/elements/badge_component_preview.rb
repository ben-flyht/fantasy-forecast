# frozen_string_literal: true

module Elements
  class BadgeComponentPreview < ViewComponent::Preview
    def default
      render BadgeComponent.new(label: "Our pick")
    end

    def with_tooltip
      render BadgeComponent.new(label: "Pro", title: "Rating of 60 or more this season")
    end
  end
end
