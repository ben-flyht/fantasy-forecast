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

  # A score as the week it describes, which is the scale the grades are read on. A
  # total shown raw would be forty points beside somebody else's four.
  #
  # Given the horizon rather than told whether it is the season, because "not the
  # season" stopped meaning "one week" the moment there were three of them: a
  # five-gameweek total divided by one was printed as though it were a single week's.
  def card_points(score, horizon)
    return "—" if score.nil?

    format("%.1f", score / Horizon.find(horizon).divisor)
  end
end
