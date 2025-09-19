require "application_system_test_case"

class UserAuthenticationTest < ApplicationSystemTestCase
  test "prophet can sign up" do
    visit new_user_registration_path

    fill_in "Username", with: "TestProphet"
    fill_in "Email", with: "test@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"

    click_button "Sign up"

    assert_text "Welcome! You have signed up successfully."

    # Verify user was created with correct role
    user = User.find_by(email: "test@example.com")
    assert user.present?
    assert user.prophet?
    assert_equal "TestProphet", user.username
  end

  test "prophet can log in and log out" do
    # Create a test user first
    user = User.create!(
      email: "prophet@test.com",
      username: "TestProphet",
      password: "password123",
      role: "prophet"
    )

    # Test login
    visit new_user_session_path

    fill_in "Email", with: "prophet@test.com"
    fill_in "Password", with: "password123"

    click_button "Log in"

    assert_text "Signed in successfully."

    # Test logout
    click_link "Logout"

    assert_text "Signed out successfully."
  end

  test "admin can log in" do
    # Create an admin user
    admin = User.create!(
      email: "admin@test.com",
      username: "TestAdmin",
      password: "password123",
      role: "admin"
    )

    visit new_user_session_path

    fill_in "Email", with: "admin@test.com"
    fill_in "Password", with: "password123"

    click_button "Log in"

    assert_text "Signed in successfully."

    # Verify it's the admin user
    assert admin.admin?
  end

  test "invalid login shows error" do
    visit new_user_session_path

    fill_in "Email", with: "nonexistent@test.com"
    fill_in "Password", with: "wrongpassword"

    click_button "Log in"

    assert_text "Invalid Email or password."
  end
end