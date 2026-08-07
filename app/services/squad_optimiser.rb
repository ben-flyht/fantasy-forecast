# The best fifteen £100.0m can buy for one gameweek.
#
# What we are maximising is not the squad's expected points. A substitute only scores
# when a starter does not play, so the eleven count in full and the bench counts by how
# often each of its places actually gets used. Maximising the squad flat would buy an
# expensive bench that mostly sits there; maximising the eleven alone would buy four
# passengers who score nothing on the week somebody is injured in the warm-up.
#
# The search is a hill climb: swap one player for another of the same position, keep
# the swap if the squad is worth more and still legal, repeat until nothing helps.
# Two things about that are load-bearing and were both learned the hard way.
#
# It starts from the cheapest legal fifteen. Starting from the best eleven starts over
# budget, and a climb that only accepts affordable swaps can never repair its way back
# down to £100.0m.
#
# It starts several times. A single start found a squad worth 63.32 where a better
# start found 64.77, and nothing about the first answer looked wrong. One basin of
# attraction is not allowed to decide this.
class SquadOptimiser < ApplicationService
  BUDGET = 1000                      # tenths of a million, as FPL counts money
  CLUB_LIMIT = 3
  QUOTAS = { "goalkeeper" => 2, "defender" => 5, "midfielder" => 5, "forward" => 3 }.freeze
  SQUAD_SIZE = QUOTAS.values.sum

  # Every shape FPL allows: a keeper, and ten outfield who must include at least three
  # defenders and one forward.
  FORMATIONS = (3..5).to_a.product((2..5).to_a, (1..3).to_a)
                     .select { |defenders, midfielders, forwards| defenders + midfielders + forwards == 10 }
                     .freeze

  # The chance a given starter does not play at all: injured late, dropped, rested.
  # Every bench weight below follows from this one number.
  MISS_RATE = 0.07

  OUTFIELD_STARTERS = 10

  MAX_ROUNDS = 300

  def initialize(gameweek:, horizon: "gameweek")
    @gameweek = gameweek
    @horizon = horizon
  end

  def call
    return if pool.size < SQUAD_SIZE

    formation, squad = best_of(starting_points)
    return if squad.nil?

    persist(formation, squad)
  end

  private

  attr_reader :gameweek, :horizon

  # Players we would actually pick. A flagged player is a different bet from the one
  # the forecast is making, so he is not one of them.
  def pool
    @pool ||= Forecast.where(gameweek: gameweek, horizon: horizon)
                      .includes(player: :team)
                      .filter_map { |forecast| candidate(forecast) }
  end

  def candidate(forecast)
    player = forecast.player
    return unless pickable?(player, forecast)

    cost = costs.dig(player.id, "now_cost")
    return if cost.nil? || cost.zero?

    { player_id: player.id, position: player.position, team_id: player.team_id,
      cost: cost.to_i, expected_points: forecast.score.to_f }
  end

  def pickable?(player, forecast)
    return false if player.nil? || player.departed || !player.selectable
    return false if player.status.present? && player.status != "a"

    forecast.score.present?
  end

  def costs
    @costs ||= Statistic.where(type: "now_cost").latest_by_player
  end

  def by_position
    @by_position ||= pool.group_by { |candidate| candidate[:position] }
                         .transform_values { |candidates| candidates.sort_by { |c| -c[:expected_points] } }
  end

  # How often each bench place is used. The first substitute comes on if any of the ten
  # outfield starters does not play, the second if two of them do not, and the reserve
  # keeper only if our own keeper does not.
  def bench_weights
    @bench_weights ||= {
      0 => at_least(1), 1 => at_least(2), 2 => at_least(3), keeper: MISS_RATE
    }
  end

  def at_least(count)
    1 - (0...count).sum { |k| combinations(OUTFIELD_STARTERS, k) * MISS_RATE**k * (1 - MISS_RATE)**(OUTFIELD_STARTERS - k) }
  end

  def combinations(n, k) = (1..k).reduce(1) { |total, i| total * (n - i + 1) / i }

  # ---- the search -------------------------------------------------------------

  def starting_points
    @starting_points ||= [ cheapest_legal_squad ] +
                         FORMATIONS.map { |formation| climb(cheapest_legal_squad) { |squad| eleven_points(squad, formation) } }
  end

  def best_of(starts)
    best = distinct(starts).filter_map { |start| best_from(start) }.max_by(&:last)
    best&.first(2)
  end

  def distinct(starts)
    starts.compact.select { |squad| squad.size == SQUAD_SIZE }
          .uniq { |squad| squad.map { |pick| pick[:player_id] }.sort }
  end

  # The best this starting point can reach, over every shape it could be played in.
  def best_from(start)
    FORMATIONS.filter_map do |formation|
      squad = climb(start) { |candidate| worth(candidate, formation) }
      next if total_cost(squad) > BUDGET

      [ formation, squad, worth(squad, formation) ]
    end.max_by(&:last)
  end

  def cheapest_legal_squad
    QUOTAS.each_with_object([]) do |(position, needed), squad|
      by_position.fetch(position, []).sort_by { |c| [ c[:cost], -c[:expected_points] ] }.each do |candidate|
        break if squad.count { |pick| pick[:position] == position } >= needed

        trial = squad + [ candidate ]
        squad.replace(trial) if within_club_limit?(trial)
      end
    end
  end

  def climb(squad, &worth_of)
    MAX_ROUNDS.times do
      improved = swap_round(squad, &worth_of)
      squad = improved || break
    end
    squad
  end

  # One pass over the squad, taking the first swap that helps each player. Returns the
  # improved squad, or nil when nothing in the pool beats what we already hold.
  def swap_round(squad, &worth_of)
    changed = false

    squad.each_index do |index|
      replacement = better_swap(squad, index, &worth_of)
      next if replacement.nil?

      squad = replacement
      changed = true
    end

    changed ? squad : nil
  end

  def better_swap(squad, index, &worth_of)
    current = worth_of.call(squad)

    replacements_for(squad, index).each do |incoming|
      trial = squad.dup
      trial[index] = incoming
      return trial if legal?(trial) && worth_of.call(trial) > current + Float::EPSILON
    end

    nil
  end

  def replacements_for(squad, index)
    held = squad.map { |pick| pick[:player_id] }
    by_position.fetch(squad[index][:position], []).reject { |pick| held.include?(pick[:player_id]) }
  end

  def legal?(squad) = affordable?(squad) && within_club_limit?(squad)

  # ---- scoring ----------------------------------------------------------------

  # The eleven that would start, given the shape: the best keeper we own, then the best
  # of each outfield position the formation asks for.
  def eleven(squad, formation)
    defenders, midfielders, forwards = formation
    keeper = squad.select { |pick| pick[:position] == "goalkeeper" }.max_by { |pick| pick[:expected_points] }
    outfield = { "defender" => defenders, "midfielder" => midfielders, "forward" => forwards }
      .flat_map { |position, count| best_at(squad, position, count) }

    [ keeper, *outfield ].compact
  end

  def best_at(squad, position, count)
    squad.select { |pick| pick[:position] == position }
         .sort_by { |pick| -pick[:expected_points] }
         .first(count)
  end

  # What the eleven is expected to score, armband included.
  #
  # The captain's points are doubled, and the armband goes on the best player in the
  # side, so an eleven is worth its own total plus its best man again. Leaving that out
  # did not just report a smaller number, it searched for a different squad: doubling
  # the top score changes what the budget is willing to pay for one great player rather
  # than two good ones.
  def eleven_points(squad, formation)
    starting = eleven(squad, formation)

    starting.sum { |pick| pick[:expected_points] } + armband(starting)
  end

  def armband(starting)
    starting.map { |pick| pick[:expected_points] }.max.to_f
  end

  # The eleven in full, plus each bench place discounted by how often it is used.
  def worth(squad, formation)
    eleven_points(squad, formation) + bench_value(squad - eleven(squad, formation))
  end

  # Each place on the bench is worth its player discounted by how often it is used.
  def bench_value(substitutes)
    keepers, outfield = substitutes.partition { |pick| pick[:position] == "goalkeeper" }
    outfield_value(outfield) + reserve_keeper_value(keepers)
  end

  def outfield_value(outfield)
    outfield.sort_by { |pick| -pick[:expected_points] }
            .each_with_index
            .sum { |pick, place| pick[:expected_points] * bench_weights.fetch(place, 0) }
  end

  def reserve_keeper_value(keepers)
    keepers.sum { |pick| pick[:expected_points] * bench_weights[:keeper] }
  end

  # ---- rules ------------------------------------------------------------------

  def affordable?(squad) = total_cost(squad) <= BUDGET

  def within_club_limit?(squad)
    squad.group_by { |pick| pick[:team_id] }.each_value.none? { |club| club.size > CLUB_LIMIT }
  end

  def total_cost(squad) = squad.sum { |pick| pick[:cost] }

  # ---- writing it down --------------------------------------------------------

  def persist(formation, squad)
    Squad.upsert_all([ row_for(formation, squad) ], unique_by: %i[gameweek_id horizon])
    Squad.find_by(gameweek: gameweek, horizon: horizon)
  end

  def row_for(formation, squad)
    starting = eleven(squad, formation)
    now = Time.current

    { gameweek_id: gameweek.id, horizon: horizon, formation: formation.join("-"),
      cost: total_cost(squad), expected_points: eleven_points(squad, formation),
      picks: squad.map { |pick| pick.merge(starting: starting.include?(pick)) },
      created_at: now, updated_at: now }
  end
end
