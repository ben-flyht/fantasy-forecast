# frozen_string_literal: true

class FieldComponent < ViewComponent::Base
  renders_one :action

  def initialize(name:, label:, value: nil, type: :text, help: nil, error: nil, **input_attributes)
    @name = name
    @label = label
    @value = value
    @type = type
    @help = help
    @error = error
    @input_attributes = input_attributes
  end

  private

  attr_reader :name, :label, :help, :error

  def input
    public_send("#{@type}_field_tag", name, @value, **@input_attributes,
                aria: { describedby: (help_id if help) },
                class: "block w-full min-w-0 flex-1 rounded-control border border-line-strong bg-surface px-3 py-2.5 text-base")
  end

  def help_id = "#{name}-help"
end
