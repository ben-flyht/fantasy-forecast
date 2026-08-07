# frozen_string_literal: true

# A player in a column rather than a row.
#
# The wide card is 96px tall and reads left to right, which is right for a list and
# wrong for a pair: two of them side by side on a phone leaves each about 165px, and
# a name set across that wraps or clips.
#
# So this one stacks: his picture, his name, his club and price, his grade. Narrow
# enough that two stand beside each other at 320px, which is the width a comparison
# has to survive because a comparison is two things or it is nothing.
class PlayerCompactCardComponent < PlayerRowComponent
  private

  # The headline number under the name. A ranking has a place in a list; a pair has
  # only the points, which is the thing actually being compared.
  def headline
    @leading
  end

  def headline?
    @leading.present?
  end

  # A badge is drawn twice: once knocked out to a silhouette so it reads against the
  # colour, once in its own colours over the top. Which way it is knocked out depends
  # on whether the club plays in something pale.
  def badge_silhouette
    team&.on_light? ? "brightness-0" : "brightness-0 invert"
  end
end
