require "test_helper"

class PlayerSearchTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)          # Mohamed Salah
    @palmer = players(:midfielder_two)     # Cole Palmer
    @brazilian = players(:brazilian)       # Igor Jesus Maciel da Cruz
    Rails.cache.clear
  end

  def search(term, **options) = PlayerSearch.call(term: term, **options)

  test "a last name finds him" do
    assert_includes search("salah"), @salah
  end

  test "a first name finds him too, because that is the name some are known by" do
    assert_includes search("cole"), @palmer
  end

  test "a few letters is enough" do
    assert_includes search("pal"), @palmer
  end

  test "case is not something a reader should have to get right" do
    assert_includes search("SALAH"), @salah
  end

  # Nobody types the umlaut.
  test "accents are folded away on both sides" do
    accented = Player.create!(first_name: "Viktor", last_name: "Gyökeres", short_name: "Gyökeres",
                              fpl_id: 9901, team: @salah.team, position: "forward")

    assert_includes search("gyokeres"), accented
    assert_includes search("Gyökeres"), accented
  end

  # Somebody typing "sal" means Salah before he means anyone with those letters in
  # the middle of a name.
  test "a name that starts with what you typed comes before one that merely contains it" do
    buried = Player.create!(first_name: "Ken", last_name: "Marsalah", short_name: "Marsalah",
                            fpl_id: 9902, team: @salah.team, position: "defender")

    assert_equal @salah, search("salah").first
    assert_includes search("salah"), buried
  end

  test "nothing typed is nothing found" do
    assert_empty search("")
    assert_empty search(nil)
    assert_empty search("   ")
  end

  test "a name nobody has finds nobody" do
    assert_empty search("zzzznobody")
  end

  # A player already picked is not a candidate for the other half of his own
  # comparison.
  test "a player can be excluded by his address" do
    assert_not_includes search("salah", exclude: [ @salah.to_param ]), @salah
  end

  test "a player can be excluded by his id, as older addresses name him" do
    assert_not_includes search("salah", exclude: [ @salah.id.to_s ]), @salah
  end

  test "it returns no more than it was asked for" do
    assert_operator search("a", limit: 2).size, :<=, 2
  end

  # Two players with the same name, and the one the whole game owns is the one
  # somebody probably meant.
  test "the more owned of two matches comes first" do
    rival = Player.create!(first_name: "Mohamed", last_name: "Salahi", short_name: "Salahi",
                           fpl_id: 9903, team: @salah.team, position: "midfielder")
    Statistic.create!(player: @salah, gameweek: gameweeks(:next_gw), type: "selected_by_percent", value: 55.0)
    Statistic.create!(player: rival, gameweek: gameweeks(:next_gw), type: "selected_by_percent", value: 1.0)
    Rails.cache.clear

    assert_equal @salah, search("salah").first
  end
end
