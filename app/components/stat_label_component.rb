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
               class: "cursor-help underline decoration-line-strong decoration-dotted underline-offset-2 " \
                      "hover:decoration-muted")
  end

  def definition
    tag.span(term.definition, id: popover_id, popover: "auto", role: "tooltip",
             class: "m-auto max-w-xs rounded-control bg-surface px-4 py-3 text-left text-sm font-normal normal-case " \
                    "tracking-normal text-body shadow-lg ring-1 ring-line backdrop:bg-ink/10")
  end

  def popover_id
    @popover_id ||= "stat-#{SecureRandom.hex(4)}"
  end
end
