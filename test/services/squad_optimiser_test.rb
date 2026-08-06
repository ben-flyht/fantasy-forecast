require "test_helper"

class SquadOptimiserTest < ActiveSupport::TestCase
  setup do
    Squad.destroy_all
    Statistic.destroy_all
    Forecast.destroy_all
    Player.destroy_all
    Gameweek.destroy_all
    Team.destroy_all

    @gameweek = Gameweek.create!(fpl_id: 1, name: "Gameweek 1", start_time: 3.days.from_now, is_next: true)
    @teams = 6.times.map do |i|
      Team.create!(fpl_id: 900 + i, code: 900 + i, name: "Club #{i}", short_name: "C#{i}")
    end
  end

  # Enough of everyone to fill a squad several times over, priced so that the good
  # players cannot all be afforded at once.
  def build_pool(counts: { "goalkeeper" => 6, "defender" => 15, "midfielder" => 15, "forward" => 9 })
    id = 0
    counts.each do |position, count|
      count.times do |i|
        id += 1
        player = Player.create!(first_name: "P", last_name: "#{position.capitalize}#{i}",
                                short_name: "#{position[0, 3].upcase}#{i}", fpl_id: 9000 + id,
                                code: 9000 + id, team: @teams[id % @teams.size], position: position)
        # Better players cost more, so the budget has to choose.
        points = (count - i).to_f / 2
        Forecast.create!(player: player, gameweek: @gameweek, horizon: "gameweek",
                         rank: i + 1, score: points)
        Statistic.create!(player: player, gameweek: @gameweek, type: "now_cost",
                          value: 40 + (points * 20).round)
      end
    end
  end

  test "it picks a squad that obeys every one of FPL's rules" do
    build_pool
    squad = SquadOptimiser.call(gameweek: @gameweek)

    assert_not_nil squad
    assert_equal 15, squad.picks.size
    assert_equal 11, squad.starters.size
    assert_equal 4, squad.substitutes.size

    quotas = squad.picks.group_by { |pick| pick["position"] }.transform_values(&:size)
    assert_equal SquadOptimiser::QUOTAS.stringify_keys, quotas

    assert squad.cost <= SquadOptimiser::BUDGET, "spent #{squad.cost} of #{SquadOptimiser::BUDGET}"

    per_club = Player.where(id: squad.player_ids).group(:team_id).count.values
    assert per_club.max <= SquadOptimiser::CLUB_LIMIT, "#{per_club.max} from one club"
  end

  test "the starting eleven is a shape FPL allows" do
    build_pool
    squad = SquadOptimiser.call(gameweek: @gameweek)
    starting = squad.starters.group_by { |pick| pick["position"] }.transform_values(&:size)

    assert_equal 1, starting["goalkeeper"]
    assert_includes 3..5, starting["defender"]
    assert_includes 2..5, starting["midfielder"]
    assert_includes 1..3, starting["forward"]
    assert_equal squad.formation, [ starting["defender"], starting["midfielder"], starting["forward"] ].join("-")
  end

  # Both sides of this are an eleven, so the comparison is like for like: the same
  # shape, filled with the cheapest bodies rather than searched for.
  test "its eleven beats the cheapest eleven of the same shape" do
    build_pool
    squad = SquadOptimiser.call(gameweek: @gameweek)
    defenders, midfielders, forwards = squad.formation.split("-").map(&:to_i)

    cheapest = { "goalkeeper" => 1, "defender" => defenders,
                 "midfielder" => midfielders, "forward" => forwards }.sum do |position, count|
      Player.where(position: position).joins(:forecasts)
            .where(forecasts: { gameweek: @gameweek, horizon: "gameweek" })
            .joins("JOIN statistics ON statistics.player_id = players.id AND statistics.type = 'now_cost'")
            .order("statistics.value ASC").limit(count)
            .pluck("forecasts.score").sum
    end

    assert squad.expected_points > cheapest,
           "searched #{squad.expected_points} should beat the cheap #{cheapest} eleven"
  end

  test "a player FPL has flagged is never picked" do
    build_pool
    flagged = Player.where(position: "midfielder").first
    flagged.update!(status: "i")

    squad = SquadOptimiser.call(gameweek: @gameweek)
    assert_not_includes squad.player_ids, flagged.id
  end

  test "it writes one squad per gameweek and horizon, and rewrites rather than duplicates" do
    build_pool
    first = SquadOptimiser.call(gameweek: @gameweek)
    second = SquadOptimiser.call(gameweek: @gameweek)

    assert_equal 1, Squad.where(gameweek: @gameweek, horizon: "gameweek").count
    assert_equal first.id, second.id
  end

  test "too small a pool produces nothing rather than an illegal squad" do
    build_pool(counts: { "goalkeeper" => 1, "defender" => 2, "midfielder" => 2, "forward" => 1 })

    assert_nil SquadOptimiser.call(gameweek: @gameweek)
  end
end
