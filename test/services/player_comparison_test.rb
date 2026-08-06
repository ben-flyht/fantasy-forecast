require "test_helper"

class PlayerComparisonTest < ActiveSupport::TestCase
  setup do
    # Fixture players share these positions, and a comparison reads the whole
    # field, so the field has to be the one the test builds.
    Forecast.destroy_all
    Statistic.destroy_all
    Player.destroy_all

    @team = Team.create!(fpl_id: 920, name: "Compare City", short_name: "CMC", code: 920)
    @rival_team = Team.create!(fpl_id: 921, name: "Compare Rovers", short_name: "CMR", code: 921)
    @gameweek = Gameweek.create!(fpl_id: 96, name: "Gameweek 96", start_time: 2.days.from_now, is_next: true)

    @player = build_player("Subject", 9600, @team, cost: 75, score: 4.0)
    @teammate = build_player("Teammate", 9601, @team, cost: 90, score: 6.0)
    @cheap_teammate = build_player("Cheap", 9602, @team, cost: 45, score: 1.0)
    @same_price = build_player("Same", 9603, @rival_team, cost: 80, score: 5.0)
    @far_dearer = build_player("Dearer", 9604, @rival_team, cost: 120, score: 9.0)
    @cheaper = build_player("Cheaper", 9605, @rival_team, cost: 55, score: 3.0)
  end

  def build_player(name, fpl_id, team, cost:, score:)
    player = Player.create!(first_name: name, last_name: "Player", short_name: name,
                            fpl_id: fpl_id, code: fpl_id, team: team, position: "midfielder")
    Statistic.create!(player: player, gameweek: @gameweek, type: "now_cost", value: cost)
    Forecast.create!(player: player, gameweek: @gameweek, horizon: "gameweek", score: score, rank: fpl_id - 9600 + 1)
    player
  end

  def comparison(player = @player)
    PlayerComparison.call(player: player, gameweek: @gameweek, horizon: "gameweek")
  end

  test "his club's players in his position are ranked by the forecast on show" do
    names = comparison.rivals.map { |entry| entry.player.short_name }

    assert_equal %w[Teammate Subject Cheap], names
  end

  test "he is marked in his own list" do
    subject = comparison.rivals.find(&:subject?)

    assert_equal @player, subject.player
    assert_equal 2, subject.place
    assert_equal 3, subject.of
  end

  # A squad player is exactly the one who falls outside a top five, and whether he
  # is in the side is the question the table exists to answer.
  test "a player outside the shortlist is still shown, at his real place" do
    9.times { |index| build_player("Better#{index}", 9700 + index, @team, cost: 60, score: 8.0 + index) }

    subject = comparison.rivals.find(&:subject?)

    assert_not_nil subject, "the player whose page it is must never drop out of his own table"
    assert_equal 11, subject.place
    assert_equal 12, subject.of
    assert_equal PlayerComparison::RIVALS + 1, comparison.rivals.size
  end

  # Half a million above is the upgrade most managers can find without selling
  # somebody else to pay for it, so it counts as affordable.
  test "affordable means his price or less, plus half a million of headroom" do
    names = comparison.alternatives.map { |entry| entry.player.short_name }

    assert_includes names, "Same", "eighty is within half a million above seventy-five"
    assert_includes names, "Cheaper"
    assert_not_includes names, "Dearer", "a hundred and twenty is well past the headroom"
    assert_not_includes names, "Subject", "he is not an alternative to himself"
  end

  test "only three are offered, best forecast first" do
    5.times { |index| build_player("Option#{index}", 9800 + index, @rival_team, cost: 70, score: 7.0 + index) }

    entries = comparison.alternatives

    assert_equal PlayerComparison::ALTERNATIVES, entries.size
    assert_equal %w[Option4 Option3 Option2], entries.map { |entry| entry.player.short_name }
  end

  # Where nothing affordable beats him the three shown are the closest anything
  # gets, which is as useful an answer as a list of upgrades.
  test "where nobody affordable is better, the closest are shown and said to be no upgrade" do
    Forecast.where(player: [ @same_price, @cheaper, @cheap_teammate ]).find_each { |f| f.update!(score: 1.0) }

    refute comparison.upgrade?
    assert_equal 3, comparison.alternatives.size
  end

  test "an upgrade is reported when one of them beats him" do
    assert comparison.upgrade?, "Same is forecast 5.0 against his 4.0"
  end

  test "a card is given the rank and grade it needs to draw itself" do
    entry = comparison.alternatives.first

    assert_equal entry.player.id, entry.ranking.player_id
    assert_equal entry.rank, entry.ranking.bot_rank
    assert_not_nil entry.ranking.grade
    assert entry.facts.key?("now_cost")
  end

  test "a season grade is read on the same scale as a single week" do
    weekly = comparison.alternatives.first.grade
    seasonal = PlayerComparison.call(player: @player, gameweek: @gameweek, horizon: "gameweek",
                                     divisor: 38).alternatives.first.grade

    assert_not_equal weekly, seasonal, "a season total spread over 38 weeks cannot grade the same"
  end

  test "a player we hold no price for is compared with nobody" do
    Statistic.where(player: @player, type: "now_cost").destroy_all

    assert_nil comparison.cost
    assert_empty comparison.alternatives
  end

  test "a player with no club has no teammates to lose his place to" do
    @player.update!(team: nil)

    assert_empty comparison.rivals
  end

  test "a player nobody has forecast sorts below one we have, rather than above" do
    Forecast.where(player: @teammate).destroy_all

    names = comparison.rivals.map { |entry| entry.player.short_name }

    assert_equal %w[Subject Cheap Teammate], names, "unknown is not the same as good"
  end
end
