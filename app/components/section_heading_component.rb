# frozen_string_literal: true

class SectionHeadingComponent < ViewComponent::Base
  renders_one :action, ->(label:, url:) { ButtonComponent.new(label: label, href: url, class: "shrink-0") }

  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end

  private

  attr_reader :title, :subtitle
end
