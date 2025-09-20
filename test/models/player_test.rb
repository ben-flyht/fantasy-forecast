require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "should require first_name" do
    player = Player.new(last_name: "Player", team: "Arsenal", position: "forward", fpl_id: 123)
    assert_not player.valid?
    assert_includes player.errors[:first_name], "can't be blank"
  end

  test "should require last_name" do
    player = Player.new(first_name: "Test", team: "Arsenal", position: "forward", fpl_id: 123)
    assert_not player.valid?
    assert_includes player.errors[:last_name], "can't be blank"
  end

  test "should require team" do
    player = Player.new(first_name: "Test", last_name: "Player", position: "forward", fpl_id: 123)
    assert_not player.valid?
    assert_includes player.errors[:team], "can't be blank"
  end

  test "should require fpl_id" do
    player = Player.new(first_name: "Test", last_name: "Player", team: "Arsenal", position: "forward")
    assert_not player.valid?
    assert_includes player.errors[:fpl_id], "can't be blank"
  end

  test "should require unique fpl_id" do
    player1 = Player.create!(
      first_name: "Test",
      last_name: "Player1",
      team: "Arsenal",
      position: "forward",
      fpl_id: 123
    )

    player2 = Player.new(
      first_name: "Test",
      last_name: "Player2",
      team: "Chelsea",
      position: "midfielder",
      fpl_id: 123
    )

    assert_not player2.valid?
    assert_includes player2.errors[:fpl_id], "has already been taken"
  end

  test "should accept valid positions" do
    player = Player.new(first_name: "Test", last_name: "Player", team: "Arsenal", fpl_id: 123)

    # Valid positions
    %w[goalkeeper defender midfielder forward].each do |position|
      player.position = position
      assert player.valid?, "#{position} should be valid"
    end
  end

  test "short_name is optional" do
    player = Player.new(
      first_name: "Test",
      last_name: "Player",
      team: "Arsenal",
      position: "forward",
      fpl_id: 123
    )
    assert player.valid?
  end

  test "should create valid player with all fields" do
    player = Player.new(
      first_name: "Test",
      last_name: "Player",
      short_name: "Player",
      team: "Arsenal",
      position: "forward",
      fpl_id: 123
    )
    assert player.valid?
    assert player.save
  end

  test "name method should concatenate first_name and last_name" do
    player = Player.new(
      first_name: "Test",
      last_name: "Player",
      team: "Arsenal",
      position: "forward",
      fpl_id: 123
    )
    assert_equal "Test Player", player.name
  end

  test "enum scopes should work" do
    # Clear existing players to ensure clean test
    Player.destroy_all

    goalkeeper = Player.create!(
      first_name: "Goal",
      last_name: "Keeper",
      team: "Arsenal",
      position: "goalkeeper",
      fpl_id: 1
    )

    defender = Player.create!(
      first_name: "Def",
      last_name: "Ender",
      team: "Arsenal",
      position: "defender",
      fpl_id: 2
    )

    midfielder = Player.create!(
      first_name: "Mid",
      last_name: "Fielder",
      team: "Arsenal",
      position: "midfielder",
      fpl_id: 3
    )

    forward = Player.create!(
      first_name: "For",
      last_name: "Ward",
      team: "Arsenal",
      position: "forward",
      fpl_id: 4
    )

    assert_includes Player.goalkeeper, goalkeeper
    assert_includes Player.defender, defender
    assert_includes Player.midfielder, midfielder
    assert_includes Player.forward, forward

    assert_equal 1, Player.goalkeeper.count
    assert_equal 1, Player.defender.count
    assert_equal 1, Player.midfielder.count
    assert_equal 1, Player.forward.count
  end
end