require "net/http"
require "json"

class FplSyncPlayers
  FPL_API_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"

  def self.call
    new.call
  end

  def call
    Rails.logger.info "Starting FPL player sync..."

    data = fetch_fpl_data
    return false unless data

    teams = build_teams_hash(data["teams"])
    elements = data["elements"]

    sync_players(elements, teams)

    Rails.logger.info "FPL player sync completed. Total players: #{Player.count}"
    true
  rescue => e
    Rails.logger.error "FPL sync failed: #{e.message}"
    false
  end

  private

  def fetch_fpl_data
    uri = URI(FPL_API_URL)

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "FantasyProphet App"

      response = http.request(request)

      if response.code == "200"
        JSON.parse(response.body)
      else
        Rails.logger.error "FPL API returned #{response.code}: #{response.message}"
        nil
      end
    end
  end

  def build_teams_hash(teams_data)
    teams_hash = {}
    teams_data.each do |team|
      teams_hash[team["id"]] = team["name"]
    end
    teams_hash
  end

  def sync_players(elements, teams)
    position_map = {
      1 => "GK",
      2 => "DEF",
      3 => "MID",
      4 => "FWD"
    }

    elements.each do |element|
      fpl_id = element["id"]
      name = "#{element['first_name']} #{element['second_name']}".strip
      team = teams[element["team"]]
      position = position_map[element["element_type"]]

      # Skip if we can't determine position or team
      next unless position && team

      player_attributes = {
        name: name,
        team: team,
        position: position
      }

      player = Player.find_or_initialize_by(fpl_id: fpl_id)
      player.assign_attributes(player_attributes)

      if player.save
        Rails.logger.debug "Synced player: #{name} (#{team}, #{position})"
      else
        Rails.logger.warn "Failed to sync player #{name}: #{player.errors.full_messages.join(', ')}"
      end
    end
  end
end
