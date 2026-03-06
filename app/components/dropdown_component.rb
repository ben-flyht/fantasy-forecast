# frozen_string_literal: true

class DropdownComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(label:, name:, options:, selected: nil, form: nil, draft_category: nil)
    @label = label
    @name = name
    @options = options
    @selected = selected
    @form = form
    @draft_category = draft_category
  end

  def select_classes
    base = "appearance-none relative isolate inline-flex items-center justify-center gap-x-2 rounded-lg border text-sm/6 font-semibold pl-3 pr-8 py-1.5 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 cursor-default"
    if @draft_category
      "#{base} #{draft_style(@draft_category, :border)} #{draft_style(@draft_category, :background)} #{draft_style(@draft_category, :text)}"
    else
      "#{base} border-zinc-950/10 text-zinc-950 hover:bg-zinc-950/[2.5%] bg-white"
    end
  end

  def selected_label
    @options.find { |opt| opt[1].to_s == @selected.to_s }&.first || @options.first&.first
  end
end
