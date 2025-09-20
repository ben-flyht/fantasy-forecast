require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should require username" do
    user = User.new(email: "test@example.com", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "should require unique username" do
    user1 = User.create!(
      email: "test1@example.com",
      username: "testuser",
      password: "password123",
      role: "forecaster"
    )

    user2 = User.new(
      email: "test2@example.com",
      username: "testuser",
      password: "password123"
    )

    assert_not user2.valid?
    assert_includes user2.errors[:username], "has already been taken"
  end

  test "should have forecaster role by default" do
    user = User.new(email: "test@example.com", username: "testuser", password: "password123")
    assert user.forecaster?
    assert_not user.admin?
  end

  test "should allow admin role" do
    user = User.new(email: "test@example.com", username: "testuser", password: "password123", role: "admin")
    assert user.admin?
    assert_not user.forecaster?
  end

  test "role enum should work correctly" do
    user = User.new(email: "test@example.com", username: "testuser", password: "password123")

    user.role = "forecaster"
    assert user.forecaster?
    assert_not user.admin?

    user.role = "admin"
    assert user.admin?
    assert_not user.forecaster?
  end
end
