# frozen_string_literal: true

class DropdownComponent < ViewComponent::Base
  def initialize(label:, name:, options:, selected: nil, form: nil)
    @label = label
    @name = name
    @options = options
    @selected = selected
    @form = form
  end

  private

  def select_classes = "appearance-none pr-8 #{ButtonComponent.classes}"

  def submit
    @form ? "document.getElementById('#{@form}').requestSubmit()" : "this.form.requestSubmit()"
  end
end
