require "application_system_test_case"

# Building the argument you actually arrived holding.
#
# The pairs the hub lists are the ones our forecast puts closest together, which is
# never the pair somebody came in with, and a side is not always one player: two free
# transfers is a choice between two moves.
class ComparisonBuilderTest < ApplicationSystemTestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @raya = players(:goalkeeper)
  end

  def choose(side, slot, typed, name)
    within "[data-side='#{side}'][data-slot='#{slot}']" do
      fill_in "comparison-player-#{side}-#{slot}", with: typed
      click_button name
    end
  end

  test "two players, and the page that answers them" do
    visit comparisons_path

    choose(0, 0, "salah", @salah.full_name)
    choose(1, 0, "palmer", @palmer.full_name)
    click_button "Compare them"

    assert_current_path comparison_path(pair: Comparison.new(@salah, @palmer).slug)
  end

  test "another box appears once the one before it is filled" do
    visit comparisons_path

    assert_no_button "and another player"

    choose(0, 0, "salah", @salah.full_name)
    click_button "and another player", match: :first
    choose(0, 1, "palmer", @palmer.full_name)
    choose(1, 0, "raya", @raya.full_name)
    click_button "Compare them"

    assert_current_path comparison_path(pair: Comparison.new([ @salah, @palmer ], @raya).slug)
  end

  test "a player already picked is not offered for the other side" do
    visit comparisons_path

    choose(0, 0, "salah", @salah.full_name)

    within "[data-side='1'][data-slot='0']" do
      fill_in "comparison-player-1-0", with: "salah"
      assert_no_button @salah.full_name
    end
  end
end
