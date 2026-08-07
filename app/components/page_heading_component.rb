# frozen_string_literal: true

# How every page introduces itself: a utility row, then a title.
#
# Seven pages used to do this seven ways — three title sizes, three places to share
# from, two designs for the same horizon toggle in three positions, and a timestamp
# on one page only. The player page's heading was sr-only, so that page had no
# visible title at all.
#
# Drawn for a phone first. Everything below sm is one column with a row each, which
# is the layout you get if a breakpoint is ever wrong; from sm up the toggle and the
# timestamp pair off onto one row. The order in the markup never changes, so nothing
# is reading in a different sequence at one width than at another.
class PageHeadingComponent < ViewComponent::Base
  # A horizon a page can be read at is just one choice among a set, so it is the
  # same thing the positions on the rankings are. Sharing the struct is what stops
  # the two controls drifting into two designs again.
  Horizon = SegmentedControlComponent::Option

  # Where a page came from, for the pages that are arrived at from another one.
  Back = Struct.new(:label, :url, keyword_init: true)

  # @param share [String, nil] what is being shared, said in full. The button reads
  #   "Share"; this is what a screen reader hears and what the share sheet is titled.
  def initialize(title:, subtitle: nil, updated_at: nil, share: nil, back: nil, horizons: nil)
    @title = title
    @subtitle = subtitle
    @updated_at = updated_at
    @share = share
    @back = back
    @horizons = horizons.presence
  end

  private

  attr_reader :title, :subtitle, :updated_at, :share, :back, :horizons

  # The row above the title. A page with neither a way back nor anything to share
  # does not draw it at all rather than drawing it empty.
  def utility_row? = back.present? || share.present?

  def utility_alignment = back.present? ? "justify-between" : "justify-end"

  # Where the timestamp sits, which depends on whether there is a second row at all.
  #
  # Beside the toggle when there is one: they are both things you do to the page
  # rather than things the page says. With no toggle there is no second row to join,
  # so it pairs with the title instead. Dropped to the left on its own it sat directly
  # under the subtitle and read as a third line of it rather than as a note of when
  # this was worked out.
  def updated_placement
    return "sm:col-start-2 sm:row-start-2 sm:justify-self-end" if horizons

    "sm:col-start-2 sm:row-start-1 sm:justify-self-end sm:self-center"
  end

  # The title only spans the grid when something else needs the row beneath it.
  def title_placement
    horizons ? "sm:col-span-full sm:row-start-1" : "sm:col-start-1 sm:row-start-1"
  end
end
