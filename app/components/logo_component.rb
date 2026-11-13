# frozen_string_literal: true

class LogoComponent < ViewComponent::Base
  def initialize(size: nil, inverse: false)
    @size = size
    @inverse = inverse
  end

  def call
    tag.span(class: classes, style: ("--size: #{@size}" if @size)) do
      safe_join([ tag.span("Fantasy", class: "logo__fantasy"), tag.span("Forecast", class: "logo__forecast") ])
    end
  end

  private

  def classes = @inverse ? "logo logo--inverse" : "logo"
end
