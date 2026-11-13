# frozen_string_literal: true

module Layout
  class EmptyStateComponentPreview < ViewComponent::Preview
    def default
      render EmptyStateComponent.new(title: "No squad yet",
                                     message: "There is no forecast for gameweek 12 to build one from.")
    end

    def message_only
      render EmptyStateComponent.new(message: "Nobody has locked in a pack yet.")
    end

    def with_link
      render_with_template
    end
  end
end
