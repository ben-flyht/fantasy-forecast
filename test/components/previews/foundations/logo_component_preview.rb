# frozen_string_literal: true

module Foundations
  class LogoComponentPreview < ViewComponent::Preview
    def default
      render LogoComponent.new
    end

    def inverse
      render_with_template
    end

    # @param size text
    def sized(size: "2rem")
      render LogoComponent.new(size: size)
    end
  end
end
