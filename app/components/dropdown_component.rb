# frozen_string_literal: true

class DropdownComponent < ViewComponent::Base
  def initialize(label:, name:, options:, selected: nil)
    @label = label
    @name = name
    @options = options
    @selected = selected
  end

  def selected_label
    @options.find { |opt| opt[1].to_s == @selected.to_s }&.first || @options.first&.first
  end
end
