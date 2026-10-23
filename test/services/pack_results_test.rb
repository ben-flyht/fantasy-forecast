require "test_helper"

class PackResultsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    [ PackEntry, WeeklyPack, Manager, Performance, Statistic, Forecast, Player, Gameweek, Team ].each(&:destroy_all)
    @gameweek = Gameweek.create!(fpl_id: 8, name: "Gameweek 8", start_time: 3.days.from_now, is_next: true)
    players = build_pack_pool(@gameweek)
    @weekly = WeeklyPack.for(@gameweek)
    score = PackScore.new(@weekly.pack)
    @hand = score.forecast
    @entry = @weekly.pack_entries.create!(manager: Manager.create!(email: "ed@example.com", nickname: "Ed"),
                                          hand: @hand.code, expected_points: score.points(@hand))

    players.each_with_index do |player, index|
      Performance.create!(player: player, gameweek: @gameweek, team: player.team, gameweek_score: index % 7)
      Statistic.create!(player: player, gameweek: @gameweek, type: "minutes", value: 90)
    end
  end

  test "nothing goes out before the gameweek is finished" do
    assert_no_emails { PackResults.call }
    assert_nil @entry.reload.results_sent_at
  end

  test "once it is finished, each manager is emailed once and the marks are kept" do
    @gameweek.update!(start_time: 3.days.ago, is_next: false, is_finished: true)

    assert_emails(1) { PackResults.call }
    @entry.reload
    assert @entry.results_sent_at
    assert_equal PackRealScore.new(@gameweek).for(@hand).points, @entry.real_points
    assert_in_delta @entry.forecast_accuracy, @entry.accuracy, 0.0001
    assert_operator @entry.accuracy, :<=, 1.0

    assert_no_emails { PackResults.call }
  end

  test "the email says how you did against the forecast" do
    @gameweek.update!(start_time: 3.days.ago, is_next: false, is_finished: true)
    Gameweek.create!(fpl_id: 9, name: "Gameweek 9", start_time: 4.days.from_now, is_next: true)

    PackResults.call

    mail = ActionMailer::Base.deliveries.last
    assert_match "Gameweek 8", mail.subject
    assert_match "level with the forecast", mail.subject
    assert_match "1st of 1", mail.text_part.body.to_s
    assert_match "Gameweek 9 pack", mail.text_part.body.to_s
  end
end
