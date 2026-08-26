# The players standing either side of this one.
#
# A forecast on its own is a number without a scale. Two comparisons give it one,
# and they are the two questions a manager actually asks:
#
#   will he even play   - who else at his club wants his shirt
#   could I do better   - who this money, or a little more, would buy instead
#
# Both are answered from forecasts already stored for the horizon on show, so the
# page never disagrees with the rankings it links back to.
class PlayerComparison < ApplicationService
  # Enough to see the pecking order without listing a reserve team.
  RIVALS = 5

  # Three names is a decision. A longer list is a search, and the reader came here
  # with a team already picked.
  ALTERNATIVES = 3

  # How far above his price still counts as affordable, in FPL's tenths of a
  # million. Half a million is the step FPL prices move in, and it is the upgrade
  # most managers can find without selling somebody else to pay for it.
  HEADROOM = 5

  COST = "now_cost".freeze
  OWNERSHIP = "selected_by_percent".freeze
  FACT_TYPES = [ COST, OWNERSHIP ].freeze

  # place is where he comes in the whole field being compared, and of is how big
  # that field is, so a row can say "7th of 11" however short the shortlist is.
  Entry = Struct.new(:player, :score, :rank, :cost, :subject, :place, :of, :grade, :facts,
                     keyword_init: true) do
    alias_method :subject?, :subject

    # What a player card needs to draw itself: where he ranks and how he grades.
    def ranking
      ConsensusRanking::Ranking.new(
        player_id: player.id, name: player.short_name, team_id: player.team_id,
        position: player.position, bot_rank: rank, score: score, grade: grade
      )
    end
  end

  # divisor spreads a rest-of-season score back over the weeks it covers, so a
  # grade on a card reads on the same scale as the grade in the panel above it.
  def initialize(player:, gameweek:, horizon:, divisor: 1)
    @player = player
    @gameweek = gameweek
    @horizon = horizon
    @divisor = divisor
  end

  def call
    self
  end

  # Everyone at his club who plays where he plays, best first, him among them.
  #
  # The largest single term in a forecast is how much of a match a player is
  # expected to be on the pitch for, so who else is competing for that shirt
  # belongs on the page rather than buried inside a multiplier.
  def rivals
    return [] if @player.team_id.nil?

    @rivals ||= shortlist(entries_for(squad), RIVALS)
  end

  # The three best players this money would buy instead.
  #
  # Affordable means his price or less, plus the half-million most managers can
  # find, so a genuine upgrade is not hidden behind a rounding of the budget.
  #
  # Sorted best first and cut at three, which answers both halves of the question
  # at once: where three beat him they are the three to consider, and where none
  # do, the three shown are the closest anything cheaper gets. Either way the
  # reader learns whether the money is on the right player.
  def alternatives
    return [] if cost.nil?

    @alternatives ||= entries_for(affordable_players).reject(&:subject?).first(ALTERNATIVES)
  end

  # Whether any of them is actually forecast to beat him.
  def upgrade?
    return false if score.nil?

    alternatives.any? { |entry| entry.score.to_f > score }
  end

  # How many players inside the budget are forecast to beat him, out of how many
  # there are. Counted over the whole affordable field and not over the three on
  # show, because the page says "defenders at seven million or less" and then
  # counts, and the reader takes the count to be of the thing just named. Three
  # of three read as "only three defenders beat him" for a man lying a hundred
  # and seventy-sixth.
  def beaten_by
    return [ 0, 0 ] if cost.nil? || score.nil?

    affordable = entries_for(affordable_players).reject(&:subject?)
    [ affordable.count { |entry| entry.score.to_f > score }, affordable.size ]
  end

  # What we forecast for the player whose page this is.
  def score
    @score ||= forecasts[@player.id]&.score&.to_f
  end

  # The most anything on the shortlist costs, so the page can say what it asked of
  # the budget rather than making the reader read the column.
  def ceiling
    cost && cost + HEADROOM
  end

  # What he costs, so the page can say what each alternative saves.
  def cost
    costs[@player.id]
  end

  private

  def squad
    Player.where(team_id: @player.team_id, position: @player.position).to_a
  end

  def affordable_players
    ids = costs.select { |_id, price| price <= ceiling }.keys
    Player.where(position: @player.position, id: ids).where.not(team_id: nil).to_a
  end

  # The best few, and him.
  #
  # A shortlist that drops the player whose page it is answers a question nobody
  # asked. The whole point of ranking him against his teammates is to find out
  # whether he is in the side, and a squad player is precisely the one who falls
  # outside the top five. So he is put back, at his real place in the order.
  def shortlist(entries, limit)
    best = entries.first(limit)
    return best if best.any?(&:subject?)

    best + entries.select(&:subject?)
  end

  # Ordered by the forecast on show, with players we cannot forecast last: unknown
  # is not the same as good, which is how the rankings themselves order it too.
  def entries_for(players)
    numbered(players.map { |player| entry_for(player) }.sort_by { |entry| order_of(entry) })
  end

  def order_of(entry)
    [ entry.score ? 0 : 1, -(entry.score || 0), entry.player.short_name.to_s ]
  end

  def numbered(entries)
    entries.each_with_index do |entry, index|
      entry.place = index + 1
      entry.of = entries.size
    end
  end

  def entry_for(player)
    forecast = forecasts[player.id]
    points = forecast&.score&.to_f
    Entry.new(
      player: player, score: points, rank: forecast&.rank, cost: costs[player.id],
      subject: player.id == @player.id, grade: grade_for(points), facts: facts[player.id] || {}
    )
  end

  # Read on the same scale as the panel above: a season total is spread back over
  # the weeks it covers before it meets the grade bands.
  def grade_for(points)
    return "-" if points.nil?

    TierCalculator.grade_from_points(points / @divisor)
  end

  def forecasts
    @forecasts ||= Forecast.where(gameweek: @gameweek, horizon: @horizon).index_by(&:player_id)
  end

  # Every price and ownership in the position, asked for once. The alternatives
  # need the whole field to find who is affordable, and the squad's figures come
  # free with it.
  def facts
    @facts ||= Statistic.where(player_id: position_ids, type: FACT_TYPES).latest_by_player
  end

  def costs
    @costs ||= facts.transform_values { |stats| stats[COST] }.compact
  end

  def position_ids
    @position_ids ||= Player.where(position: @player.position).pluck(:id)
  end
end
