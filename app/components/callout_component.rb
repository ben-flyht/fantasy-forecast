# frozen_string_literal: true

class CalloutComponent < ViewComponent::Base
  BODY_TONES = {
    muted: "text-body",
    outline: "text-body",
    dark: "text-inverse-muted"
  }.freeze

  def initialize(title:, eyebrow: nil, url: nil, tone: :muted, **attributes)
    @title = title
    @eyebrow = eyebrow
    @url = url
    @tone = tone
    @attributes = attributes
  end

  private

  attr_reader :title, :eyebrow, :url, :tone, :attributes

  def dark? = tone == :dark

  def eyebrow_classes = dark? ? "eyebrow text-faint" : "eyebrow"

  def title_classes = "text-headline #{dark? ? 'text-white' : 'text-ink'}"

  def body_classes = "mt-3 max-w-2xl text-copy #{BODY_TONES.fetch(tone)}"
end
