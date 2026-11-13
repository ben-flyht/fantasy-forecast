# frozen_string_literal: true

class EmptyStateComponent < ViewComponent::Base
  def initialize(title: nil, message: nil, **attributes)
    @title = title
    @message = message
    @attributes = attributes
  end

  private

  attr_reader :title, :message, :attributes
end
