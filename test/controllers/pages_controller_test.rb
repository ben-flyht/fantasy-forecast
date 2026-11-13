require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get root_url
    assert_response :success
  end

  test "should get privacy_policy" do
    get privacy_policy_url
    assert_response :success
  end

  test "should get terms_of_service" do
    get terms_of_service_url
    assert_response :success
  end

  test "should get cookie_policy" do
    get cookie_policy_url
    assert_response :success
  end

  test "should get contact_us" do
    get contact_us_url
    assert_response :success
  end

  test "each legal page names itself in the browser tab" do
    { privacy_policy_url => "Privacy Policy", terms_of_service_url => "Terms of Service",
      cookie_policy_url => "Cookie Policy", contact_us_url => "Contact Us" }.each do |url, name|
      get url
      assert_select "title", "#{name} | Fantasy Forecast"
    end
  end
end
