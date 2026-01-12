require "test_helper"

class GoogleNews::FetchPlayerNewsTest < ActiveSupport::TestCase
  def setup
    @team = Team.find_or_create_by!(fpl_id: 600) do |t|
      t.name = "Test Team"
      t.short_name = "TST"
    end

    @player = Player.create!(
      fpl_id: 6000,
      first_name: "Test",
      last_name: "Player",
      position: "forward",
      team: @team
    )
  end

  test "returns empty array when GOOGLE_API_KEY not set" do
    original_api_key = ENV["GOOGLE_API_KEY"]
    ENV["GOOGLE_API_KEY"] = nil

    result = GoogleNews::FetchPlayerNews.call(player: @player)
    assert_equal [], result
  ensure
    ENV["GOOGLE_API_KEY"] = original_api_key
  end

  test "builds correct search query with player name, team and position" do
    service = GoogleNews::FetchPlayerNews.new(player: @player)
    query = service.send(:build_query)

    assert_includes query, @player.full_name
    assert_includes query, @team.name
    assert_includes query, @player.position
  end

  test "builds query without team when player has no team" do
    @player.update!(team: nil)
    service = GoogleNews::FetchPlayerNews.new(player: @player)
    query = service.send(:build_query)

    assert_includes query, @player.full_name
    assert_includes query, @player.position
  end

  test "caches results for subsequent calls" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    original_api_key = ENV["GOOGLE_API_KEY"]
    original_cse_id = ENV["GOOGLE_CSE_ID"]

    ENV["GOOGLE_API_KEY"] = "test_key"
    ENV["GOOGLE_CSE_ID"] = "test_cse"

    # Stub the HTTP request
    stub_request(:get, /googleapis.com\/customsearch/)
      .to_return(
        status: 200,
        body: { items: [ { title: "Test Article", snippet: "Test", link: "http://test.com", displayLink: "test.com" } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # First call - populates cache
    GoogleNews::FetchPlayerNews.call(player: @player)

    # Verify cache key was populated
    cache_key = "player_news/v2/player:#{@player.id}"
    assert Rails.cache.exist?(cache_key), "Cache should have been populated"
  ensure
    Rails.cache = original_cache
    ENV["GOOGLE_API_KEY"] = original_api_key
    ENV["GOOGLE_CSE_ID"] = original_cse_id
  end

  test "normalizes article data correctly" do
    service = GoogleNews::FetchPlayerNews.new(player: @player)

    raw_item = {
      title: "Player scores hat-trick",
      snippet: "Test Player scored three goals...",
      link: "https://example.com/article",
      displayLink: "example.com",
      pagemap: {
        cse_image: [ { src: "https://example.com/image.jpg" } ]
      }
    }

    normalized = service.send(:normalize_article, raw_item)

    assert_equal "Player scores hat-trick", normalized[:title]
    assert_equal "Test Player scored three goals...", normalized[:snippet]
    assert_equal "https://example.com/article", normalized[:url]
    assert_equal "example.com", normalized[:source]
    assert_equal "https://example.com/image.jpg", normalized[:image]
  end

  test "handles missing image gracefully" do
    service = GoogleNews::FetchPlayerNews.new(player: @player)

    raw_item = {
      title: "Article without image",
      snippet: "Some text",
      link: "https://example.com/article",
      displayLink: "example.com"
    }

    normalized = service.send(:normalize_article, raw_item)

    assert_nil normalized[:image]
  end

  test "returns empty array when API not configured" do
    original_api_key = ENV["GOOGLE_API_KEY"]
    original_cse_id = ENV["GOOGLE_CSE_ID"]

    ENV["GOOGLE_API_KEY"] = nil
    ENV["GOOGLE_CSE_ID"] = nil

    result = GoogleNews::FetchPlayerNews.call(player: @player)
    assert_equal [], result
  ensure
    ENV["GOOGLE_API_KEY"] = original_api_key
    ENV["GOOGLE_CSE_ID"] = original_cse_id
  end

  test "cache key includes player id" do
    service = GoogleNews::FetchPlayerNews.new(player: @player)
    cache_key = service.send(:cache_key)

    assert_includes cache_key, @player.id.to_s
    assert_includes cache_key, "player_news"
  end
end
