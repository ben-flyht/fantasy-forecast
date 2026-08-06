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
