require "test_helper"

module Fpl
  class SyncGameweeksTest < ActiveSupport::TestCase
    def setup
      # Clear existing data to avoid fixture conflicts
      Prediction.destroy_all
      Gameweek.destroy_all

      @service = SyncGameweeks.new
      @api_url = "https://fantasy.premierleague.com/api/bootstrap-static/"
      @mock_api_response = {
        "events" => [
          {
            "id" => 1,
            "name" => "Gameweek 1",
            "deadline_time" => "2024-08-16T17:30:00Z",
            "is_current" => false,
            "is_next" => false,
            "finished" => true
          },
          {
            "id" => 2,
            "name" => "Gameweek 2",
            "deadline_time" => "2024-08-23T17:30:00Z",
            "is_current" => true,
            "is_next" => false,
            "finished" => false
          },
          {
            "id" => 3,
            "name" => "Gameweek 3",
            "deadline_time" => "2024-08-30T17:30:00Z",
            "is_current" => false,
            "is_next" => true,
            "finished" => false
          }
        ]
      }
    end

    test "call creates new gameweeks from API data" do
      stub_request(:get, @api_url)
        .to_return(status: 200, body: @mock_api_response.to_json, headers: { 'Content-Type' => 'application/json' })

      assert_difference "Gameweek.count", 3 do
        assert SyncGameweeks.call
      end

      # Check first gameweek
      gw1 = Gameweek.find_by(fpl_id: 1)
      assert_not_nil gw1
      assert_equal "Gameweek 1", gw1.name
      assert_equal Time.parse("2024-08-16T17:30:00Z"), gw1.start_time
      assert_equal Time.parse("2024-08-23T17:30:00Z") - 1.second, gw1.end_time
      assert_equal false, gw1.is_current
      assert_equal false, gw1.is_next
      assert_equal true, gw1.is_finished

      # Check current gameweek
      gw2 = Gameweek.find_by(fpl_id: 2)
      assert_not_nil gw2
      assert_equal "Gameweek 2", gw2.name
      assert_equal true, gw2.is_current

      # Check next gameweek
      gw3 = Gameweek.find_by(fpl_id: 3)
      assert_not_nil gw3
      assert_equal "Gameweek 3", gw3.name
      assert_equal true, gw3.is_next
      assert_nil gw3.end_time # Last gameweek has no end_time
    end

    test "call updates existing gameweeks" do
      # Create existing gameweek
      existing_gw = Gameweek.create!(
        fpl_id: 1,
        name: "Old Name",
        start_time: Time.current - 1.day,
        is_current: true
      )

      stub_request(:get, @api_url)
        .to_return(status: 200, body: @mock_api_response.to_json, headers: { 'Content-Type' => 'application/json' })

      assert_difference "Gameweek.count", 2 do # Only 2 new gameweeks created
        assert SyncGameweeks.call
      end

      existing_gw.reload
      assert_equal "Gameweek 1", existing_gw.name
      assert_equal Time.parse("2024-08-16T17:30:00Z"), existing_gw.start_time
      assert_equal false, existing_gw.is_current
      assert_equal true, existing_gw.is_finished
    end

    test "call resets current and next flags before processing" do
      # Create gameweeks with current/next flags
      old_current = Gameweek.create!(
        fpl_id: 99,
        name: "Old Current",
        start_time: Time.current,
        is_current: true
      )

      old_next = Gameweek.create!(
        fpl_id: 100,
        name: "Old Next",
        start_time: Time.current + 1.week,
        is_next: true
      )

      stub_request(:get, @api_url)
        .to_return(status: 200, body: @mock_api_response.to_json, headers: { 'Content-Type' => 'application/json' })

      SyncGameweeks.call

      old_current.reload
      old_next.reload

      assert_equal false, old_current.is_current
      assert_equal false, old_next.is_next

      # New current/next should be set from API
      new_current = Gameweek.find_by(fpl_id: 2)
      new_next = Gameweek.find_by(fpl_id: 3)

      assert_equal true, new_current.is_current
      assert_equal true, new_next.is_next
    end

    test "call calculates end_time correctly" do
      stub_request(:get, @api_url)
        .to_return(status: 200, body: @mock_api_response.to_json, headers: { 'Content-Type' => 'application/json' })

      SyncGameweeks.call

      gw1 = Gameweek.find_by(fpl_id: 1)
      gw2 = Gameweek.find_by(fpl_id: 2)
      gw3 = Gameweek.find_by(fpl_id: 3)

      # First gameweek end_time should be second gameweek start_time - 1 second
      assert_equal Time.parse("2024-08-23T17:30:00Z") - 1.second, gw1.end_time

      # Second gameweek end_time should be third gameweek start_time - 1 second
      assert_equal Time.parse("2024-08-30T17:30:00Z") - 1.second, gw2.end_time

      # Last gameweek should have no end_time
      assert_nil gw3.end_time
    end

    test "call returns false when API request fails" do
      stub_request(:get, @api_url).to_timeout

      assert_equal false, SyncGameweeks.call
      assert_equal 0, Gameweek.count
    end

    test "call returns false when API returns non-200 status" do
      stub_request(:get, @api_url)
        .to_return(status: 404, body: "Not Found")

      assert_equal false, SyncGameweeks.call
      assert_equal 0, Gameweek.count
    end

    test "call handles invalid gameweek data gracefully" do
      invalid_response = {
        "events" => [
          {
            "id" => 1,
            "name" => "Gameweek 1",
            "deadline_time" => "2024-08-16T17:30:00Z"
          },
          {
            "id" => 2,
            "name" => "Gameweek 2",
            "deadline_time" => "invalid-date" # Invalid date
          }
        ]
      }

      stub_request(:get, @api_url)
        .to_return(status: 200, body: invalid_response.to_json, headers: { 'Content-Type' => 'application/json' })

      # Should not crash and should create valid gameweeks
      assert SyncGameweeks.call
      assert_equal 1, Gameweek.count # Only valid gameweek created

      # Valid gameweek should be created correctly
      gw1 = Gameweek.find_by(fpl_id: 1)
      assert_not_nil gw1
      assert_equal "Gameweek 1", gw1.name
    end

    test "class method call delegates to instance" do
      stub_request(:get, @api_url)
        .to_return(status: 200, body: @mock_api_response.to_json, headers: { 'Content-Type' => 'application/json' })

      # Test that the class method works (it calls new.call internally)
      assert SyncGameweeks.call
      assert_equal 3, Gameweek.count
    end
  end
end