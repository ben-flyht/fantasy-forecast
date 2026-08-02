require "test_helper"

class AvailabilityTest < ActiveSupport::TestCase
  setup do
    Gameweek.destroy_all
    @team = Team.create!(fpl_id: 900, name: "Test United", short_name: "TUD", code: 900)
    # Ten weekly gameweeks starting a week from now.
    @gameweeks = (1..10).map do |week|
      Gameweek.create!(fpl_id: 900 + week, name: "Gameweek #{900 + week}", start_time: week.weeks.from_now)
    end
    @posted = 1.day.ago
  end

  def player(status:, news: nil, fpl_id: 9100)
    Player.create!(first_name: "Test", last_name: "Player#{fpl_id}", short_name: "T#{fpl_id}",
                   fpl_id: fpl_id, code: fpl_id, team: @team, position: "defender",
                   status: status, news: news, news_added: @posted)
  end

  def share_for(player)
    Availability.call([ player ], gameweeks: @gameweeks)[player.id]
  end

  test "a fit player is left alone, so the model reads FPL's own flag" do
    assert_empty Availability.call([ player(status: "a") ], gameweeks: @gameweeks)
  end

  test "a player who has left the league is out for all of it" do
    gone = player(status: "u", news: "Has joined Grimsby Town on loan for the rest of the season")

    assert_equal 0.0, share_for(gone)
  end

  test "a named return date counts only the weeks before it" do
    back = @gameweeks.fourth.start_time.strftime("%-d %b")
    injured = player(status: "i", news: "Groin injury - Expected back #{back}")

    # Back for the fourth week onwards: seven of the ten.
    assert_in_delta 0.7, share_for(injured), 0.001
  end

  test "a suspension is read the same way as an injury" do
    until_date = @gameweeks.third.start_time.strftime("%-d %b")
    banned = player(status: "s", news: "Suspended until #{until_date}")

    assert_in_delta 0.8, share_for(banned), 0.001
  end

  test "over a season, an unknown return date is a long absence and not a permanent one" do
    injured = player(status: "i", news: "Back injury - Unknown return date")
    season = @gameweeks + (11..38).map do |week|
      Gameweek.create!(fpl_id: 900 + week, name: "Gameweek #{900 + week}", start_time: week.weeks.from_now)
    end

    share = Availability.call([ injured ], gameweeks: season)[injured.id]
    assert share.positive?, "a player with no return date is still coming back"
    assert share < 1.0, "and is not treated as fit in the meantime"
  end

  test "with only a few weeks left, a long absence really does rule a player out" do
    injured = player(status: "i", news: "Back injury - Unknown return date")

    assert_equal 0.0, share_for(injured), "ten weeks is inside the assumed layoff"
  end

  test "a doubt costs the coming week and no more" do
    doubtful = player(status: "d", news: "Knee injury - 75% chance of playing")

    # Nine full weeks plus three quarters of one.
    assert_in_delta 0.975, share_for(doubtful), 0.001
  end

  test "a flag still flying long after its return date does not read as fit" do
    stale = player(status: "i", news: "Knee injury - Expected back 1 Jan")
    stale.update!(news_added: 2.years.ago)

    assert share_for(stale) < 1.0, "he misses the coming week whatever the date says"
  end

  test "unparseable news falls back to a long absence rather than raising" do
    odd = player(status: "i", news: "Injury - Expected back never")

    assert_in_delta share_for(odd), share_for(player(status: "i", news: "Knee injury - Unknown return date",
                                                    fpl_id: 9101)), 0.001
  end

  test "with no gameweeks left there is nothing to be available for" do
    assert_empty Availability.call([ player(status: "i", news: "Knee injury - Unknown return date") ],
                                   gameweeks: [])
  end
end
