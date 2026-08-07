require "test_helper"

class CaptainsControllerTest < ActionDispatch::IntegrationTest
  test "the captain page names the highest forecast in the game" do
    get captain_path

    assert_response :success
    assert_select "h1", /Who to Captain in FPL/
    assert_select "p", /#{players(:midfielder).display_name}/
  end

  # The armband is worth the same whatever position he plays, so the pick is the
  # best score in the game rather than the best score in a position.
  test "the candidates are ordered by score, not by their place in a position" do
    get captain_path

    scores = assigns_candidates.map { |candidate| candidate.score.to_f }

    assert_equal scores.sort.reverse, scores
  end

  test "a player with no score is not a captain option" do
    get captain_path

    assert_not_includes assigns_candidates.map(&:player_id), players(:injured_player).id
  end

  test "it says who he is playing, because that is half the argument" do
    get captain_path

    assert_select "p", /at home to #{teams(:chelsea).name}/
  end

  # Not knowing how many managers own a player is not the same as knowing that few
  # do, so an unowned reading names nobody rather than everybody.
  test "no ownership reading means no differential is named" do
    get captain_path

    assert_nil assigns_differential
    assert_select "dd", /no differential worth naming/
  end

  test "a lightly owned candidate is named the differential" do
    Statistic.create!(player: players(:midfielder_two), gameweek: gameweeks(:next_gw),
                      type: "selected_by_percent", value: 4.2)

    get captain_path

    assert_equal players(:midfielder_two).id, assigns_differential.player_id
    assert_select "p", /4\.2% of managers own him/
  end

  test "a widely owned candidate is not a differential" do
    Statistic.create!(player: players(:midfielder_two), gameweek: gameweeks(:next_gw),
                      type: "selected_by_percent", value: 62.0)

    get captain_path

    assert_nil assigns_differential
  end

  test "the page stands for itself and says what it answers" do
    get captain_path

    assert_select "link[rel=canonical][href=?]", "#{ApplicationHelper::BASE_URL}/captain"
    assert_select "script[type='application/ld+json']", /FAQPage/
  end

  test "it leads to the rankings the pick was read from" do
    get captain_path

    assert_select "main a[href=?]", rankings_path
    assert_select "main a[href=?]", player_path(players(:midfielder))
  end

  test "no forecast yet is a quiet page, not a broken one" do
    Forecast.delete_all

    get captain_path

    assert_response :success
    assert_select "p", /there is no captain to name/
  end

  private

  def assigns_candidates
    @controller.view_assigns["candidates"]
  end

  def assigns_differential
    @controller.view_assigns["differential"]
  end
end
