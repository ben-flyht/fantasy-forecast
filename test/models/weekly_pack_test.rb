require "test_helper"

class WeeklyPackTest < ActiveSupport::TestCase
  setup do
    [ PackEntry, WeeklyPack, Statistic, Forecast, Player, Gameweek, Team ].each(&:destroy_all)
    @gameweek = Gameweek.create!(fpl_id: 8, name: "Gameweek 8", start_time: 3.days.from_now, is_next: true)
    build_pack_pool(@gameweek)
  end

  def cards_of(pack) = pack.pairs.map { |pair| pair.cards.map(&:player_id) }

  test "everyone gets the same pack, and it stays the pack after the forecast moves" do
    first = WeeklyPack.for(@gameweek)
    Forecast.update_all("score = score * 0.5 + 0.7")

    again = WeeklyPack.find(first.id)
    assert_equal first, WeeklyPack.for(@gameweek)
    assert_equal cards_of(first.pack), cards_of(again.pack)
    assert_equal first.pack.pairs.map { |pair| pair.cards.map(&:expected_points) },
                 again.pack.pairs.map { |pair| pair.cards.map(&:expected_points) }
    assert_equal first.pack.shiny_index, again.pack.shiny_index
  end

  test "it is the pack PackDraw deals for the gameweek's seed" do
    weekly = WeeklyPack.for(@gameweek)

    assert_equal cards_of(PackDraw.call(gameweek: @gameweek, seed: weekly.seed)), cards_of(weekly.pack)
  end

  test "no pack is drawn once the deadline has passed" do
    @gameweek.update!(start_time: 1.minute.ago)

    assert_nil WeeklyPack.for(@gameweek)
  end
end
