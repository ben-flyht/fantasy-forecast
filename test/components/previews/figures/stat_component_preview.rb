# frozen_string_literal: true

module Figures
  class StatComponentPreview < ViewComponent::Preview
    def sizes
      render_with_template
    end

    def with_note
      render_with_template
    end
  end
end
