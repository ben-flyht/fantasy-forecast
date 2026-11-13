# frozen_string_literal: true

module Layout
  class SectionHeadingComponentPreview < ViewComponent::Preview
    def title_only
      render SectionHeadingComponent.new(title: "How a comparison is answered")
    end

    def with_subtitle
      render SectionHeadingComponent.new(title: "The best players in Gameweek 12",
                                         subtitle: "Whatever they play, in order of expected points.")
    end

    def with_action
      render_with_template
    end
  end
end
