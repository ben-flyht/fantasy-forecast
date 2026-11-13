# frozen_string_literal: true

class PanelComponent < ViewComponent::Base
  TONES = {
    muted: "bg-surface-muted",
    outline: "border border-line",
    strong: "border-2 border-ink",
    dark: "bg-ink text-white"
  }.freeze

  def initialize(tone: :muted, tag: :div, **attributes)
    @tone = tone
    @tag = tag
    @attributes = attributes
  end

  def call
    content_tag(@tag, content, **@attributes, class: classes)
  end

  private

  def classes
    [ "rounded-card p-panel", TONES.fetch(@tone), @attributes[:class] ].compact.join(" ")
  end
end
