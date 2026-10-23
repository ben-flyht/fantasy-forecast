ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # A PNG says how big it is in the eight bytes after its header, which is the
    # cheapest way to ask a share card whether it came out the shape social sites
    # ask for.
    def png_size(bytes)
      bytes[16, 8].unpack("N2")
    end

    # One transparent pixel, standing in for every photograph a card embeds.
    PIXEL = Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )

    # A card with players on it fetches their pictures. No test should be asking the
    # Premier League for one, and a test that quietly did would pass or fail
    # depending on whether their CDN happened to answer.
    def build_pack_pool(gameweek, counts: { "goalkeeper" => 4, "defender" => 10, "midfielder" => 10, "forward" => 6 })
      team = Team.create!(fpl_id: 990, code: 990, name: "Pool United", short_name: "PLU")
      counts.flat_map.with_index do |(position, count), group|
        count.times.map do |i|
          id = 6000 + (group * 100) + i
          player = Player.create!(first_name: "P", last_name: "#{position}#{i}", short_name: "#{position[0, 3]}#{i}",
                                  fpl_id: id, code: id, team: team, position: position)
          Forecast.create!(player: player, gameweek: gameweek, horizon: "gameweek", rank: i + 1, score: 6.0 - (i * 0.4))
          Statistic.create!(player: player, gameweek: gameweek, type: "now_cost", value: 45 + i)
          player
        end
      end
    end

    def stub_player_images
      stub_request(:get, %r{resources\.premierleague\.com/.*\.png})
        .to_return(status: 200, body: PIXEL, headers: { "Content-Type" => "image/png" })
    end
  end
end
