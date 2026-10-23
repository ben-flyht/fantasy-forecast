require "test_helper"

class ManagerTest < ActiveSupport::TestCase
  setup { Manager.destroy_all }

  test "an email is one manager however it is typed" do
    Manager.create!(email: " Ben@Example.com ", nickname: "Ben")

    assert_equal "ben@example.com", Manager.last.email
    assert_not Manager.new(email: "BEN@example.com", nickname: "Impostor").valid?
  end

  test "a name on the leaderboard is short and tidy" do
    manager = Manager.new(email: "a@example.com", nickname: "  Big   Sam  ")
    assert manager.valid?
    assert_equal "Big Sam", manager.nickname

    assert_not Manager.new(email: "b@example.com", nickname: "x" * (Manager::NICKNAME_LENGTH + 1)).valid?
    assert_not Manager.new(email: "not an email", nickname: "Nope").valid?
  end

  test "a pack link signs in its manager and nobody else, for a week" do
    manager = Manager.create!(email: "c@example.com", nickname: "C")
    token = manager.generate_token_for(:pack_link)

    assert_equal manager, Manager.find_by_token_for(:pack_link, token)
    travel 8.days do
      assert_nil Manager.find_by_token_for(:pack_link, token)
    end
  end
end
