# The bits a share card needs that a page does not: pictures carried inside the
# document, and text sized to the room it has.
module CardsHelper
  # The largest cutout the Premier League publishes. A card is a poster, and a
  # thumbnail stretched across a third of it looks like a mistake.
  PHOTO = "500x500".freeze

  def card_photo(player)
    ShareCard::Image.call(player.photo_url(size: PHOTO))
  end

  # There is no wrapping in a card, so a long name is sized down until it fits
  # rather than being allowed to run off the edge.
  def card_name_size(name)
    case name.to_s.length
    when 0..9 then 60
    when 10..13 then 48
    when 14..17 then 38
    else 32
    end
  end

  # Ink that can be read on a shirt colour. Two clubs play in something pale
  # enough that white lettering disappears into it.
  def card_ink(team)
    team&.on_light? ? "#09090b" : "#ffffff"
  end

  def card_colour(team)
    team&.color || Team::DEFAULT_COLOR
  end

  # A score as the week it describes, which is the scale the grades are read on.
  # A season total shown raw would be forty points beside somebody else's four.
  def card_points(score, season)
    return "—" if score.nil?

    format("%.1f", score / (season ? Gameweek.remaining_count : 1))
  end
end
