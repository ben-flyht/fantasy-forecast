require "test_helper"

# The three distances a forecast is read at. This was a yes-or-no until there were
# three of them, and the questions below are the ones everything else asks it: how far
# does this look, what do I divide by, and what do I call it.
class HorizonTest < ActiveSupport::TestCase
  setup do
    Gameweek.destroy_all
    @weeks = (1..10).map do |n|
      Gameweek.create!(fpl_id: n, name: "Gameweek #{n}", start_time: n.days.from_now, is_next: n == 1)
    end
  end

  test "each horizon looks over its own run of gameweeks, all starting at the next one" do
    assert_equal [ 1 ], Horizon.new("gameweek").gameweeks.pluck(:fpl_id)
    assert_equal (1..Horizon::WINDOW).to_a, Horizon.new("upcoming").gameweeks.pluck(:fpl_id)
    assert_equal (1..10).to_a, Horizon.new("season").gameweeks.pluck(:fpl_id)
  end

  # A score is divided by this to read as a single week, so a grade means the same
  # thing whichever distance it was worked out over.
  test "what it divides by is the football it actually covers, counted not assumed" do
    assert_equal 1, Horizon.new("gameweek").divisor
    assert_equal Horizon::WINDOW, Horizon.new("upcoming").divisor
    assert_equal 10, Horizon.new("season").divisor
  end

  # Near the end of a season "the next five" is however many are left, and a horizon
  # with no football in it still has to be safe to divide by.
  test "it never divides by nought, however little season is left" do
    Gameweek.where.not(fpl_id: 1).destroy_all

    assert_equal 1, Horizon.new("upcoming").divisor
    assert_equal 1, Horizon.new("season").divisor

    Gameweek.destroy_all
    assert_equal 1, Horizon.new("season").divisor
  end

  test "a horizon nobody recognises is the coming week rather than an error" do
    assert_predicate Horizon.find("nonsense"), :gameweek?
    assert_predicate Horizon.find(nil), :gameweek?
    assert_predicate Horizon.find("5"), :gameweek?
    assert_predicate Horizon.find("upcoming"), :upcoming?
  end

  # The number is written from WINDOW in every place it appears, so moving the window
  # cannot leave a label claiming a stretch of football it no longer covers.
  test "every name carrying the window is written from it" do
    upcoming = Horizon.new("upcoming")

    [ upcoming.label, upcoming.short_label, upcoming.span, upcoming.short_span ].each do |name|
      assert_includes name, Horizon::WINDOW.to_s, "#{name.inspect} does not carry the window"
    end
  end

  test "the coming week is named by its number when there is one" do
    assert_equal "Gameweek 7", Horizon.new("gameweek").label(gameweek: 7)
    assert_equal "GW7", Horizon.new("gameweek").short_label(gameweek: 7)
    assert_equal "Next Gameweek", Horizon.new("gameweek").label
  end

  # Anything spanning more than a week is a total, and a page has to say so before it
  # puts the number next to a grade calibrated for one.
  test "it knows whether its score is a total" do
    assert_not_predicate Horizon.new("gameweek"), :total?
    assert_predicate Horizon.new("upcoming"), :total?
    assert_predicate Horizon.new("season"), :total?
  end

  test "two of the same horizon are the same horizon" do
    assert_equal Horizon.new("season"), Horizon.find("season")
    assert_not_equal Horizon.new("season"), Horizon.new("upcoming")
    assert_equal 1, [ Horizon.new("season"), Horizon.find("season") ].uniq.size
  end
end
