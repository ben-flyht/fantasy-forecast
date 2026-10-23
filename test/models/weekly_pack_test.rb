require "test_helper"

class WeeklyPackTest < ActiveSupport::TestCase
  setup do
    [ PackEntry, WeeklyPack, Manager, Statistic, Forecast, Player, Gameweek, Team ].each(&:destroy_all)
    @gameweek = Gameweek.create!(fpl_id: 8, name: "Gameweek 8", start_time: 3.days.from_now, is_next: true)
    team = Team.create!(fpl_id: 993, code: 993, name: "Week City", short_name: "WKC")
    { "goalkeeper" => 4, "defender" => 8, "midfielder" => 8, "forward" => 6 }.each_with_index do |(position, count), group|
      count.times do |i|
        id = 6600 + (group * 100) + i
        player = Player.create!(first_name: "P", last_name: "#{position}#{i}", fpl_id: id, code: id, team: team, position: position)
        Forecast.create!(player: player, gameweek: @gameweek, horizon: "gameweek", rank: i + 1, score: 6.0 - (i * 0.4), working: { "minutes" => 90 })
      end
    end
  end

  def cards_of(pack) = pack.pairs.map { |pair| pair.cards.map(&:player_id) }

  test "the week's pack is drawn once and stays put when the forecast moves" do
    first = WeeklyPack.for(@gameweek)
    Forecast.update_all("score = 7.0 - score")

    assert_equal first, WeeklyPack.for(@gameweek)
    assert_equal cards_of(first.pack), cards_of(WeeklyPack.find(first.id).pack)
    assert_equal first.pack.shiny_index, WeeklyPack.find(first.id).pack.shiny_index
  end

  test "a gameweek's pack only opens once the one before it is finished" do
    previous = Gameweek.create!(fpl_id: 7, name: "Gameweek 7", start_time: 4.days.ago, is_current: true)

    assert_nil WeeklyPack.for(@gameweek)

    previous.update!(is_finished: true)
    assert WeeklyPack.for(@gameweek)
  end

  test "no pack is drawn once the deadline has passed" do
    @gameweek.update!(start_time: 1.minute.ago)

    assert_nil WeeklyPack.for(@gameweek)
  end

  test "an email has one pack a week, picked one card at a time until it is done" do
    weekly = WeeklyPack.for(@gameweek)
    manager = Manager.create!(email: " Ana@Example.com ", first_name: " Ana ", last_name: "Lopes")
    code = "a" * weekly.pack.size

    assert_equal "ana@example.com", manager.email
    assert_equal "Ana L.", manager.leaderboard_name
    entry = PackEntry.create!(manager: manager, weekly_pack: weekly, hand: "")
    code.each_char { |choice| assert entry.pick(choice) }
    assert entry.complete?
    assert_not entry.pick("a")
    assert_not PackEntry.new(manager: manager, weekly_pack: weekly, hand: "").valid?
  end
end
