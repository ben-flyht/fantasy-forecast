# frozen_string_literal: true

# A row of choices where exactly one is taken: a week or a season, a position, a
# horizon. One of them is lit, the rest are not.
#
# Every one is a link rather than a radio button, so each choice is an address. A
# crawler can follow it, a reader can bookmark it, and the control works with no
# JavaScript at all — which for the positions matters, because those four pages are
# the ones people arrive on from a search.
#
# Full width on a phone so each option is thumb-sized, its own width from sm up so it
# is not a stretched slab across a monitor.
class SegmentedControlComponent < ViewComponent::Base
  # A short_label is what the option is called when there is no room for its name:
  # GK rather than Goalkeepers. Both are in the markup and the breakpoint picks one,
  # so the link carries its full name as its accessible name either way.
  Option = Struct.new(:label, :url, :current, :short_label, keyword_init: true) do
    def current? = current
    def abbreviated? = short_label.present? && short_label != label
  end

  # @param label [String] what the group of choices is, for a screen reader
  # @param options [Array<Option>]
  def initialize(label:, options:)
    @label = label
    @options = options
  end

  def render? = options.present?

  private

  attr_reader :label, :options

  def option_classes(option)
    state = if option.current?
      "bg-white text-zinc-900 shadow-sm"
    else
      "text-zinc-500 hover:text-zinc-900"
    end

    "flex-1 sm:flex-none rounded-md px-3 py-2 text-center text-sm font-medium " \
      "transition-colors sm:px-3.5 sm:py-1.5 #{state}"
  end
end
