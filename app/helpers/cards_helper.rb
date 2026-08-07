# The bits a share card needs that a page does not: pictures carried inside the
# document, and text sized to the room it has.
module CardsHelper
  # The largest cutout the Premier League publishes. A card is a poster, and a
  # thumbnail stretched across a third of it looks like a mistake.
  PHOTO = "500x500".freeze

  def card_photo(player)
    ShareCard::Image.call(player.photo_url(size: PHOTO))
  end

  # The small cutout the site's own rows use. A row is sixty pixels tall, and the
  # poster-sized photograph would put eleven half-megabyte pictures inside one
  # document that has to be drawn while somebody waits.
  def card_cutout(player)
    ShareCard::Image.call(player&.cutout_url)
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

  # A card's paper and the inks that read on it.
  #
  # Dark came first and suits a card that is mostly one player's shirt. A card that
  # is mostly white space wants the site's own paper instead, so it looks like the
  # page it came from rather than a different product.
  THEMES = {
    dark: { paper: "#09090b", panel: "#18181b", ink: "#fafafa", quiet: "#a1a1aa",
            faint: "#71717a", rule: "#27272a", reversed: "#09090b" },
    light: { paper: "#ffffff", panel: "#f4f4f5", ink: "#09090b", quiet: "#52525b",
             faint: "#a1a1aa", rule: "#e4e4e7", reversed: "#ffffff" }
  }.freeze

  def card_theme(name = :dark)
    THEMES.fetch(name.to_sym)
  end

  # A name given the room it has rather than the size we would like it in. Nothing
  # here can measure text and there is no wrapping in a card, so the only way a long
  # name stays inside its block is to be drawn smaller.
  def card_fitted_size(text, width:, max:)
    ShareCard.fitted_size(text, width: width, max: max)
  end

  # A player as he is written on a card: his name, and the armband if he has it.
  def card_pick_name(player, captain: false)
    "#{player&.display_name.to_s.upcase}#{' (C)' if captain}"
  end

  # Ink that can be read on a shirt colour. Two clubs play in something pale
  # enough that white lettering disappears into it.
  def card_ink(team)
    team&.on_light? ? "#09090b" : "#ffffff"
  end

  def card_colour(team)
    team&.color || Team::DEFAULT_COLOR
  end

  # Past this, the decimal goes. A tenth of a point separates two players over one
  # gameweek and means nothing over thirty-eight, and a long number set at 112 point
  # runs into the artwork beside it.
  WHOLE_POINTS = 100

  # What a card is expected to score over the horizon it is drawn for, as it stands.
  #
  # It used to be divided back to the week it averages, so that every distance read
  # on the scale the grades are struck on. That answered a question nobody asks: a
  # manager looking at five gameweeks wants to know what five gameweeks are worth.
  # The grade beside it still comes from the week, because a grade is a mark out of
  # ten and has to mean the same thing at every distance.
  def card_points(score)
    return "—" if score.nil?

    score >= WHOLE_POINTS ? score.round.to_s : format("%.1f", score)
  end
end
