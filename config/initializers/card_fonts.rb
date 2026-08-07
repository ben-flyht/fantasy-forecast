# The site's typeface, for the one place a stylesheet cannot reach.
#
# A share card is drawn as SVG and rasterised by librsvg, which resolves fonts through
# fontconfig against whatever the machine happens to have installed. A dyno has almost
# nothing, so the cards were falling all the way down the font stack: every card since
# they were built has been set in something that is not Inter, and the letter-spacing
# on them was measured against Inter's outlines.
#
# Rather than a buildpack, the font ships in vendor/fonts and fontconfig is pointed at
# it the way it points at a desktop user's own fonts: XDG_DATA_HOME/fonts is already in
# the default configuration, so nothing here overrides how fonts are found, it only
# adds one more place to look. Inter is SIL Open Font Licence 1.1; see the licence
# alongside the font.
ENV["XDG_DATA_HOME"] ||= Rails.root.join("vendor").to_s
