require "test_helper"

class PackAccuracyTest < ActiveSupport::TestCase
  setup do
    [ Performance, Statistic, Forecast, Player, Gameweek, Team ].each(&:destroy_all)
    @gameweek = Gameweek.create!(fpl_id: 8, name: "Gameweek 8", start_time: 3.days.ago, is_finished: true)
    @team = Team.create!(fpl_id: 992, code: 992, name: "Mark City", short_name: "MKC")

    positions = %w[goalkeeper defender defender midfielder midfielder forward midfielder]
    pairs = positions.each_with_index.map do |position, index|
      Pack::Pair.new(slot: Pack::SLOTS[index], cards: [ card(position, 2), card(position, 6) ], shiny: index == 5)
    end
    @pack = Pack.new(seed: 1, pairs: pairs)
    @accuracy = PackAccuracy.new(@pack, PackRealScore.new(@gameweek))
  end

  def card(position, points)
    @id = (@id || 0) + 1
    player = Player.create!(first_name: "P", last_name: "#{position}#{@id}", fpl_id: 4000 + @id, code: 4000 + @id,
                            team: @team, position: position)
    Performance.create!(player: player, gameweek: @gameweek, team: @team, gameweek_score: points)
    Statistic.create!(player: player, gameweek: @gameweek, type: "minutes", value: 90)
    PickablePool::Candidate.new(player: player, rank: @id, cost: 50, expected_points: 3.0)
  end

  test "the best five in hindsight is every high scorer, with the shiny forward doubled" do
    assert_equal (6 * 5) + 6, @accuracy.best
  end

  test "keeping every high scorer is perfect, and keeping none of them is a third of it" do
    best = PackHand.parse(@pack, "bbbbbbb-26")
    worst = PackHand.parse(@pack, "aaaaaaa-26")

    assert_in_delta 1.0, @accuracy.of(best), 0.0001
    assert_in_delta 12.0 / 36, @accuracy.of(worst), 0.0001
  end
end
