require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should require username" do
    user = User.new(email: "test@example.com", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "should require unique username" do
    user1 = users(:one)

    user2 = User.new(
      email: "test2@example.com",
      username: user1.username,
      password: "password123"
    )

    assert_not user2.valid?
    assert_includes user2.errors[:username], "has already been taken"
  end

  test "should have forecasts association" do
    user = User.new(email: "test@example.com", username: "testuser", password: "password123")
    assert_respond_to user, :forecasts
  end
end
