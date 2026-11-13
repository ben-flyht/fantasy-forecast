# frozen_string_literal: true

class FaqComponent < ViewComponent::Base
  def initialize(title:, pairs:)
    @title = title
    @pairs = pairs
  end

  def before_render
    helpers.content_for :head, helpers.faq_structured_data(pairs)
  end

  private

  attr_reader :title, :pairs
end
