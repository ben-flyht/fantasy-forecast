require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "should require name" do
    player = Player.new(team: "Arsenal", position: "FWD", fpl_id: 123)
    assert_not player.valid?
    assert_includes player.errors[:name], "can't be blank"
  end

  test "should require team" do
    player = Player.new(name: "Test Player", position: "FWD", fpl_id: 123)
    assert_not player.valid?
    assert_includes player.errors[:team], "can't be blank"
  end

  test "should require fpl_id" do
    player = Player.new(name: "Test Player", team: "Arsenal", position: "FWD")
    assert_not player.valid?
    assert_includes player.errors[:fpl_id], "can't be blank"
  end

  test "should require unique fpl_id" do
    player1 = Player.create!(
      name: "Test Player 1",
      team: "Arsenal",
      position: "FWD",
      fpl_id: 123
    )

    player2 = Player.new(
      name: "Test Player 2",
      team: "Chelsea",
      position: "MID",
      fpl_id: 123
    )

    assert_not player2.valid?
    assert_includes player2.errors[:fpl_id], "has already been taken"
  end

  test "should validate position enum" do
    player = Player.new(name: "Test Player", team: "Arsenal", fpl_id: 123)

    # Valid positions
    %w[GK DEF MID FWD].each do |position|
      player.position = position
      assert player.valid?, "#{position} should be valid"
    end

    # Test enum helper methods
    player.position = "GK"
    assert player.GK?
    assert_not player.DEF?

    player.position = "DEF"
    assert player.DEF?
    assert_not player.GK?

    player.position = "MID"
    assert player.MID?
    assert_not player.FWD?

    player.position = "FWD"
    assert player.FWD?
    assert_not player.MID?
  end

  test "bye_week is optional" do
    player = Player.new(
      name: "Test Player",
      team: "Arsenal",
      position: "FWD",
      fpl_id: 123
    )
    assert player.valid?
  end

  test "should create valid player with all fields" do
    player = Player.new(
      name: "Test Player",
      team: "Arsenal",
      position: "FWD",
      bye_week: 7,
      fpl_id: 123
    )
    assert player.valid?
    assert player.save
  end
end
