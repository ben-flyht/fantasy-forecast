# frozen_string_literal: true

class StatLabelComponent < ViewComponent::Base
  def initialize(term:)
    @term = term
  end

  def call
    return ERB::Util.html_escape(term.label) unless term.defined?

    safe_join([ trigger, definition ])
  end

  private

  attr_reader :term

  def trigger
    tag.button(term.label, type: "button", popovertarget: popover_id,
               class: "cursor-help underline decoration-zinc-300 decoration-dotted underline-offset-2 " \
                      "hover:decoration-zinc-500")
  end

  def definition
    tag.span(term.definition, id: popover_id, popover: "auto", role: "tooltip",
             class: "m-auto max-w-xs rounded-lg bg-white px-4 py-3 text-left text-sm font-normal normal-case " \
                    "tracking-normal text-zinc-700 shadow-lg ring-1 ring-zinc-200 backdrop:bg-zinc-950/10")
  end

  def popover_id
    @popover_id ||= "stat-#{SecureRandom.hex(4)}"
  end
end
