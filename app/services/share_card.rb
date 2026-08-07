require "vips"

# The picture a link turns into when somebody pastes it into a group chat.
#
# Every social site shows a preview image and not one of them will accept an SVG,
# so a card is drawn as vector and rasterised here. libvips does that through
# librsvg in a few milliseconds, and both are already on the dyno, which is why
# this is not a headless browser.
class ShareCard < ApplicationService
  # What every social site asks for, and the shape they all crop to. A card drawn
  # to any other size is somebody else's crop of our design.
  WIDTH = 1200
  HEIGHT = 630

  # A card that has to carry fifteen players legibly cannot be a letterbox.
  #
  # A preview is scaled by its width, so a taller card is shown at the same scale and
  # simply has more room: the same names at the same size, with space for a club and a
  # price underneath each one. Nothing else buys that. The cost is that the sites
  # asking for 1.91:1 will crop a square, so anything a reader must see belongs in the
  # middle of it.
  SQUARE = 1200

  # How wide an uppercase letter is, as a share of its own size. Nothing here can
  # measure text, so anything that has to fit a space is fitted against this.
  # Inter's own advance is narrower than the fonts a dyno actually carries, so it
  # errs towards leaving room rather than running past the edge.
  ADVANCE = 0.72

  # Digits are narrower than letters and, in Inter, all exactly as wide as each
  # other, which is what makes a number safe to measure this way.
  DIGIT = 0.6

  # The size at which `text` fits `width`, never larger than `max`. Nothing drawing
  # a card can measure text and there is no wrapping in one, so anything that has to
  # fit a space is fitted against ADVANCE.
  def self.fitted_size(text, width:, max:)
    return max if text.blank?

    [ max, (width / (ADVANCE * text.to_s.length)).floor ].min
  end

  # How much room a string will take at a given size, so the thing after it can be
  # put down beside it rather than on top of it.
  #
  # Everything on a card is placed by hand at an absolute coordinate: there is no
  # layout engine and nothing reflows. Guessing this is how a label ends up printed
  # across the number it belongs to, which is exactly what happened before this
  # existed.
  def self.width_of(text, size:, advance: ADVANCE, tracking: 0)
    return 0 if text.blank?

    (text.to_s.length * ((advance * size) + tracking)).round
  end

  # Rails blocks the libvips readers for formats Active Storage might one day be
  # handed by a stranger, and SVG is one of them: it can name a file or a URL and
  # ask the reader to go and get it.
  #
  # Ours is markup we wrote a moment ago out of our own database, with every
  # picture already inside it, so the reader is let at that. Nothing on this site
  # takes an upload, and if that ever changes this line is the one to come back to.
  Vips.block("VipsForeignLoadSvg", false)

  def initialize(svg)
    @svg = svg
  end

  def call
    Vips::Image.svgload_buffer(@svg).write_to_buffer(".png")
  end
end
