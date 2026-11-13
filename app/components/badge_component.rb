# frozen_string_literal: true

class BadgeComponent < ViewComponent::Base
  CLASSES = "eyebrow shrink-0 rounded-badge bg-ink px-1.5 py-0.5 leading-none text-white"

  def initialize(label:, title: nil, **attributes)
    @label = label
    @title = title
    @attributes = attributes
  end

  def call
    return tag.abbr(@label, title: @title, class: "#{CLASSES} cursor-help no-underline", **@attributes) if @title

    tag.span(@label, class: CLASSES, **@attributes)
  end
end
