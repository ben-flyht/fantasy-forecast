# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  BASE = "inline-flex cursor-pointer items-center justify-center gap-1.5 rounded-control border text-sm font-medium " \
         "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-line-emphasis " \
         "focus-visible:ring-offset-2 disabled:opacity-60"

  VARIANTS = {
    outline: "border-line bg-surface text-body hover:border-line-emphasis hover:text-ink",
    solid: "border-ink bg-ink text-white hover:bg-ink/85",
    inverse: "border-surface bg-surface text-ink hover:bg-surface/85",
    ghost: "border-transparent text-muted hover:text-ink"
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5",
    md: "px-5 py-3",
    icon: "p-1.5"
  }.freeze

  def self.classes(variant: :outline, size: :sm)
    [ BASE, VARIANTS.fetch(variant), SIZES.fetch(size) ].join(" ")
  end

  def initialize(label: nil, href: nil, variant: :outline, size: :sm, type: "button", **attributes)
    @label = label
    @href = href
    @variant = variant
    @size = size
    @type = type
    @attributes = attributes
  end

  def call
    return link_to(body, @href, **@attributes, class: classes) if @href

    tag.button(body, type: @type, **@attributes, class: classes)
  end

  private

  def body = content.presence || @label

  def classes
    [ self.class.classes(variant: @variant, size: @size), @attributes[:class] ].compact.join(" ")
  end
end
