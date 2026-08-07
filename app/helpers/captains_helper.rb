module CaptainsHelper
  # Who he plays this week, said the way a manager says it. A blank gameweek has no
  # fixture and a double has two, so both are answered rather than assumed.
  def captain_fixture(player, matches)
    return "no fixture this gameweek" if matches.blank?

    matches.map { |match| fixture_phrase(player, match) }.to_sentence
  end

  private

  def fixture_phrase(player, match)
    opponent = match.opponent_for(player.team_id)&.name
    "#{match.home_for?(player.team_id) ? 'at home to' : 'away to'} #{opponent}"
  end
end
