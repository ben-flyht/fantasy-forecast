require "test_helper"

class PlayerProfileTest < ActiveSupport::TestCase
  setup do
    @team = Team.create!(fpl_id: 910, name: "Profile City", short_name: "PFC", code: 910)
    @gameweek = Gameweek.create!(fpl_id: 95, name: "Gameweek 95", start_time: 2.days.from_now, is_next: true)
    @earlier = Gameweek.create!(fpl_id: 94, name: "Gameweek 94", start_time: 9.days.ago, is_finished: true)
    @player = Player.create!(first_name: "Set", last_name: "Piece", short_name: "S.Piece",
                             fpl_id: 9500, code: 9500, team: @team, position: "midfielder",
                             birth_date: Date.new(2000, 1, 1), team_join_date: Date.new(2019, 7, 1))
  end

  def stat(type, value, gameweek: @gameweek)
    Statistic.create!(player: @player, gameweek: gameweek, type: type, value: value)
  end

  def profile
    PlayerProfile.call(player: @player, gameweek: @gameweek)
  end

  test "the man who takes them is named, and the reserves are not" do
    stat("penalties_order", 1)
    stat("corners_freekicks_order", 4)

    labels = profile.set_pieces.map(&:label)

    assert_equal [ "Penalties" ], labels, "fourth choice on corners takes none, so it says nothing"
  end

  test "a second choice says which he is" do
    stat("penalties_order", 2)

    assert_equal [ "Penalties (2nd)" ], profile.set_pieces.map(&:label)
  end

  test "duties are listed with the first choice ones first" do
    stat("direct_freekicks_order", 2)
    stat("penalties_order", 1)

    assert_equal [ "Penalties", "Free kicks (2nd)" ], profile.set_pieces.map(&:label)
  end

  test "no duty is not a duty" do
    stat("penalties_order", 0)

    assert_empty profile.set_pieces
  end

  # FPL clears a fitness flag by publishing nothing at all, so a doubt raised
  # weeks ago must not be carried into the week being read. See Forecaster.
  test "a fitness doubt is read from the gameweek in question and no earlier one" do
    stat("chance_of_playing", 25, gameweek: @earlier)

    assert_nil profile.chance_of_playing, "September's doubt is not April's"
    refute profile.doubtful?
  end

  test "a doubt raised for this week counts" do
    stat("chance_of_playing", 25)

    assert_equal 25, profile.chance_of_playing
    assert profile.doubtful?
  end

  test "a fit player is not flagged as doubtful" do
    stat("chance_of_playing", 100)

    refute profile.doubtful?
  end
end
