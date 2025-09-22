require "test_helper"

class GameweekTest < ActiveSupport::TestCase
  setup do
    # Clear existing data to avoid fixture conflicts
    Forecast.destroy_all
    Gameweek.destroy_all
  end
  test "should require fpl_id" do
    gameweek = Gameweek.new(name: "Gameweek 1", start_time: Time.current)
    assert_not gameweek.valid?
    assert_includes gameweek.errors[:fpl_id], "can't be blank"
  end

  test "should require unique fpl_id" do
    gameweek1 = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current
    )

    gameweek2 = Gameweek.new(
      fpl_id: 1,
      name: "Gameweek 2",
      start_time: Time.current + 1.week
    )

    assert_not gameweek2.valid?
    assert_includes gameweek2.errors[:fpl_id], "has already been taken"
  end

  test "should require name" do
    gameweek = Gameweek.new(fpl_id: 1, start_time: Time.current)
    assert_not gameweek.valid?
    assert_includes gameweek.errors[:name], "can't be blank"
  end

  test "should require start_time" do
    gameweek = Gameweek.new(fpl_id: 1, name: "Gameweek 1")
    assert_not gameweek.valid?
    assert_includes gameweek.errors[:start_time], "can't be blank"
  end

  test "should create valid gameweek with all required fields" do
    gameweek = Gameweek.new(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current
    )
    assert gameweek.valid?
    assert gameweek.save
  end

  test "should create valid gameweek with all fields" do
    start_time = Time.current
    end_time = start_time + 1.week

    gameweek = Gameweek.new(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: start_time,
      end_time: end_time,
      is_current: true,
      is_next: false,
      is_finished: false
    )
    assert gameweek.valid?
    assert gameweek.save
  end

  test "boolean fields default to false" do
    gameweek = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current
    )

    assert_equal false, gameweek.is_current
    assert_equal false, gameweek.is_next
    assert_equal false, gameweek.is_finished
  end

  test "end_time is optional" do
    gameweek = Gameweek.new(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current,
      end_time: nil
    )
    assert gameweek.valid?
    assert gameweek.save
  end

  test "current scope returns gameweeks with is_current true" do
    current_gw = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current,
      is_current: true
    )

    non_current_gw = Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current + 1.week,
      is_current: false
    )

    current_gameweeks = Gameweek.current
    assert_includes current_gameweeks, current_gw
    assert_not_includes current_gameweeks, non_current_gw
  end

  test "next_upcoming scope returns gameweeks with is_next true" do
    next_gw = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current + 1.week,
      is_next: true
    )

    other_gw = Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current + 2.weeks,
      is_next: false
    )

    next_gameweeks = Gameweek.next_upcoming
    assert_includes next_gameweeks, next_gw
    assert_not_includes next_gameweeks, other_gw
  end

  test "finished scope returns gameweeks with is_finished true" do
    finished_gw = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current - 1.week,
      is_finished: true
    )

    ongoing_gw = Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current,
      is_finished: false
    )

    finished_gameweeks = Gameweek.finished
    assert_includes finished_gameweeks, finished_gw
    assert_not_includes finished_gameweeks, ongoing_gw
  end

  test "current_gameweek returns the gameweek with is_current true" do
    current_gw = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current,
      is_current: true
    )

    Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current + 1.week,
      is_current: false
    )

    assert_equal current_gw, Gameweek.current_gameweek
  end

  test "current_gameweek returns nil when no current gameweek" do
    Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current,
      is_current: false
    )

    assert_nil Gameweek.current_gameweek
  end

  test "next_gameweek returns the gameweek with is_next true" do
    next_gw = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current + 1.week,
      is_next: true
    )

    Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current + 2.weeks,
      is_next: false
    )

    assert_equal next_gw, Gameweek.next_gameweek
  end

  test "next_gameweek returns nil when no next gameweek" do
    Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current + 1.week,
      is_next: false
    )

    assert_nil Gameweek.next_gameweek
  end

  test "ordered scope returns gameweeks ordered by fpl_id" do
    gw3 = Gameweek.create!(fpl_id: 3, name: "Gameweek 3", start_time: Time.current + 2.weeks)
    gw1 = Gameweek.create!(fpl_id: 1, name: "Gameweek 1", start_time: Time.current)
    gw2 = Gameweek.create!(fpl_id: 2, name: "Gameweek 2", start_time: Time.current + 1.week)

    ordered_gameweeks = Gameweek.ordered
    assert_equal [ gw1, gw2, gw3 ], ordered_gameweeks.to_a
  end
end
