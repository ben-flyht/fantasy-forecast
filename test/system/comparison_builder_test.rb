require "application_system_test_case"

# Building the argument you actually arrived holding, and changing your mind about it.
#
# The pairs the hub lists are the ones our forecast puts closest together, which is
# never the pair somebody came in with, and a side is not always one player: two free
# transfers is a choice between two moves. Building and reading are the one layout, and
# both sides filled goes straight to the page for them.
class ComparisonBuilderTest < ApplicationSystemTestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @raya = players(:goalkeeper)
  end

  # Type into a side's always-open box and take the name that comes up.
  def add(side, typed, name)
    within "[data-comparison-builder-target=side][data-side='#{side}']" do
      find("input[data-comparison-builder-target=input]").set(typed)
      click_button name
    end
  end

  test "a player on each side opens the comparison" do
    visit comparisons_path

    add(0, "salah", @salah.full_name)
    add(1, "palmer", @palmer.full_name)

    assert_current_path comparison_path(pair: Comparison.new(@salah, @palmer).slug)
  end

  test "a side can hold the players you would buy together" do
    visit comparisons_path

    add(0, "salah", @salah.full_name)
    add(0, "palmer", @palmer.full_name)
    add(1, "raya", @raya.full_name)

    assert_current_path comparison_path(pair: Comparison.new([ @salah, @palmer ], @raya).slug)
  end

  test "a player already picked is not offered for the other side" do
    visit comparisons_path

    add(0, "salah", @salah.full_name)

    within "[data-comparison-builder-target=side][data-side='1']" do
      fill_in with: "salah", id: "comparison-add-1"
      assert_no_button @salah.full_name
    end
  end

  # The comparison is edited in the same two columns it is read in. Adding a player to
  # a side takes you to the page for the sides you have now, address and all.
  test "adding a player on a comparison follows to the new sides" do
    visit comparison_path(pair: Comparison.new(@salah, @palmer).slug)

    add(0, "raya", @raya.full_name)

    assert_current_path comparison_path(pair: Comparison.new([ @salah, @raya ], @palmer).slug)
  end

  # A card carries a cross once its side holds more than one, and taking it off drops
  # back to the smaller comparison.
  test "removing a player from a side follows to the smaller comparison" do
    visit comparison_path(pair: Comparison.new([ @salah, @raya ], @palmer).slug)

    within "[data-comparison-builder-target=chip][data-param='#{@raya.to_param}']" do
      find("button[data-action='comparison-builder#remove']").click
    end

    assert_current_path comparison_path(pair: Comparison.new(@salah, @palmer).slug)
  end
end
