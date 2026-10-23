require "test_helper"

class PackTest < ActiveSupport::TestCase
  test "a pack is saved as plain rows and loaded back as the same cards" do
    team = Team.create!(fpl_id: 994, code: 994, name: "Dump City", short_name: "DMP")
    players = 2.times.map do |i|
      Player.create!(first_name: "P", last_name: "Dump#{i}", fpl_id: 6900 + i, code: 6900 + i, team: team, position: "midfielder")
    end
    cards = players.map.with_index { |player, i| Pack::Card.new(player: player, rank: i + 1, expected_points: 4.0 - i, fixtures: [ "ARS (H)" ]) }
    pack = Pack.new(pairs: [ Pack::Pair.new(slot: "midfielder", cards: cards, shiny: true) ])

    loaded = Pack.load(JSON.parse(pack.dump.to_json))

    assert_equal pack.pairs.first.cards.map(&:player_id), loaded.pairs.first.cards.map(&:player_id)
    assert_equal [ 4.0, 3.0 ], loaded.pairs.first.cards.map(&:expected_points)
    assert_equal [ "ARS (H)" ], loaded.pairs.first.cards.first.fixtures
    assert_equal 0, loaded.shiny_index
  end
end
