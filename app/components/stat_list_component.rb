# frozen_string_literal: true

class StatListComponent < ViewComponent::Base
  def initialize(rows:)
    @rows = rows
  end

  def render? = rows.present?

  private

  attr_reader :rows
end
