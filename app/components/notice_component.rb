# frozen_string_literal: true

class NoticeComponent < ViewComponent::Base
  TONES = {
    info: "bg-ink text-white",
    alert: "bg-danger-surface text-danger"
  }.freeze

  def initialize(message:, tone: :info, **attributes)
    @message = message
    @tone = tone
    @attributes = attributes
  end

  def render? = @message.present?

  def call
    tag.p(@message, **@attributes, class: classes)
  end

  private

  def classes
    [ "rounded-control px-4 py-3 text-sm", TONES.fetch(@tone), @attributes[:class] ].compact.join(" ")
  end
end
