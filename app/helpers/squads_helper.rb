module SquadsHelper
  # Football's own two-letter positions, not FPL's three: they stand where a ranking
  # puts a player's place in the list, and that column is sized for something short.
  # Midfielder is MF rather than MD, which is not an abbreviation anybody uses.
  POSITION_LETTERS = {
    "goalkeeper" => "GK", "defender" => "DF", "midfielder" => "MF", "forward" => "FW"
  }.freeze

  def position_letter(position)
    POSITION_LETTERS.fetch(position, "?")
  end

  # A pick in the terms the rankings' row asks for, so the squad can be drawn by the
  # component the rankings are drawn by. Cost is handed over as a fact because that
  # is where the row reads it from, and it is the pick's own price rather than
  # today's: what he cost is part of what we recommended.
  def pick_arguments(squad, pick, players)
    {
      ranking: squad.ranking_for(pick),
      player: players[pick["player_id"]],
      facts: { "now_cost" => pick["cost"] },
      leading: position_letter(pick["position"]),
      captain: pick == squad.captain
    }
  end
end
