class OpponentForm
  WEIGHT = 0.25
  PRIOR_MATCHES = 4.0
  XG_SPREAD = 0.35

  def self.before(gameweek)
    new(played_meetings(Gameweek.where(fpl_id: ...gameweek.fpl_id)))
  end

  def self.played_meetings(gameweeks = Gameweek.all)
    played = gameweeks.where(is_finished: true).pluck(:id)
    meetings(::Match.where(gameweek_id: played), team_xg(played))
  end

  def self.team_xg(gameweek_ids)
    Statistic.where(type: "expected_goals", gameweek_id: gameweek_ids)
             .joins("JOIN performances ON performances.player_id = statistics.player_id " \
                    "AND performances.gameweek_id = statistics.gameweek_id")
             .group("performances.team_id", "statistics.gameweek_id").sum(:value)
  end

  def self.meetings(matches, xg)
    games = matches.flat_map { |match| sides(match) }.tally
    matches.filter_map do |match|
      home, away = sides(match)
      next unless xg.key?(home) && xg.key?(away)

      { home: home.first, away: away.first, home_xg: per_game(xg, games, home), away_xg: per_game(xg, games, away) }
    end
  end

  def self.per_game(xg, games, side)
    xg[side].to_f / games[side]
  end

  def self.sides(match)
    [ [ match.home_team_id, match.gameweek_id ], [ match.away_team_id, match.gameweek_id ] ]
  end

  def initialize(meetings)
    @meetings = meetings
    @league = meetings.sum { |meeting| meeting[:home_xg] + meeting[:away_xg] } / (2.0 * meetings.size) if meetings.any?
    @rates = {}
  end

  def ratings(opponent_id, difficulty)
    return {} if @league.nil? || opponent_id.nil?

    fdr = difficulty || ExpectedPoints::AVERAGE_DIFFICULTY
    conceded, created = rates(opponent_id)
    { attack: blend(fdr, ExpectedPoints::AVERAGE_DIFFICULTY - (conceded - @league) / XG_SPREAD),
      defence: blend(fdr, ExpectedPoints::AVERAGE_DIFFICULTY + (created - @league) / XG_SPREAD) }
  end

  def rates(team_id)
    @rates[team_id] ||= begin
      played = @meetings.select { |meeting| [ meeting[:home], meeting[:away] ].include?(team_id) }
      [ shrunk(played.sum { |meeting| conceded_by(team_id, meeting) }, played.size),
        shrunk(played.sum { |meeting| created_by(team_id, meeting) }, played.size) ]
    end
  end

  private

  def conceded_by(team_id, meeting)
    meeting[:home] == team_id ? meeting[:away_xg] : meeting[:home_xg]
  end

  def created_by(team_id, meeting)
    meeting[:home] == team_id ? meeting[:home_xg] : meeting[:away_xg]
  end

  def shrunk(total, games)
    (total + PRIOR_MATCHES * @league) / (games + PRIOR_MATCHES)
  end

  def blend(fdr, form)
    WEIGHT * form + (1 - WEIGHT) * fdr
  end
end
