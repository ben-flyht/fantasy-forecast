require "test_helper"

class PackMailerTest < ActionMailer::TestCase
  test "the email carries a link that signs its manager in" do
    Manager.destroy_all
    manager = Manager.create!(email: "dee@example.com", nickname: "Dee")
    gameweek = Gameweek.new(fpl_id: 8)

    mail = PackMailer.with(manager: manager, gameweek: gameweek).pack_link

    assert_equal [ "dee@example.com" ], mail.to
    assert_match "Gameweek 8", mail.subject
    token = mail.text_part.body.to_s[%r{/pack/sign-in/(\S+)}, 1]
    assert_equal manager, Manager.find_by_token_for(:pack_link, token)
  end
end
