require "net/http"
require "json"

module Fpl
  class SyncGameweeks
    FPL_API_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"

    def self.call
      new.call
    end

    def call
      Rails.logger.info "Starting FPL gameweek sync..."

      data = fetch_fpl_data
      return false unless data

      events = data["events"]
      sync_gameweeks(events)

      # Also sync matches/fixtures
      fixtures_data = fetch_fixtures_data
      if fixtures_data
        sync_matches(fixtures_data)
      else
        Rails.logger.warn "Could not fetch fixtures data"
      end

      Rails.logger.info "FPL gameweek sync completed. Total gameweeks: #{Gameweek.count}, Total matches: #{Match.count}"
      true
    rescue => e
      Rails.logger.error "FPL gameweek sync failed: #{e.message}"
      false
    end

    private

    def fetch_fpl_data
      uri = URI(FPL_API_URL)

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Fantasy Forecast App"

        response = http.request(request)

        if response.code == "200"
          JSON.parse(response.body)
        else
          Rails.logger.error "FPL API returned #{response.code}: #{response.message}"
          nil
        end
      end
    end

    def fetch_fixtures_data
      uri = URI("https://fantasy.premierleague.com/api/fixtures/")

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Fantasy Forecast App"

        response = http.request(request)

        if response.code == "200"
          JSON.parse(response.body)
        else
          Rails.logger.error "FPL Fixtures API returned #{response.code}: #{response.message}"
          nil
        end
      end
    end

    def sync_matches(fixtures_data)
      Rails.logger.info "Syncing matches..."

      success_count = 0
      skip_count = 0
      error_count = 0

      fixtures_data.each do |fixture|
        begin
          fpl_id = fixture["id"]
          gameweek_fpl_id = fixture["event"]
          home_team_fpl_id = fixture["team_h"]
          away_team_fpl_id = fixture["team_a"]

          # Skip if essential data is missing
          unless fpl_id && gameweek_fpl_id && home_team_fpl_id && away_team_fpl_id
            Rails.logger.warn "Skipping fixture #{fpl_id}: missing essential data"
            skip_count += 1
            next
          end

          # Find the gameweek and teams
          gameweek = Gameweek.find_by(fpl_id: gameweek_fpl_id)
          home_team = Team.find_by(fpl_id: home_team_fpl_id)
          away_team = Team.find_by(fpl_id: away_team_fpl_id)

          unless gameweek && home_team && away_team
            Rails.logger.warn "Skipping fixture #{fpl_id}: gameweek=#{gameweek&.name}, home=#{home_team&.name}, away=#{away_team&.name}"
            skip_count += 1
            next
          end

          match_attributes = {
            home_team: home_team,
            away_team: away_team,
            gameweek: gameweek
          }

          match = Match.find_or_initialize_by(fpl_id: fpl_id)
          match.assign_attributes(match_attributes)

          if match.save
            Rails.logger.debug "Synced match: #{home_team.short_name} vs #{away_team.short_name} (GW#{gameweek.fpl_id})"
            success_count += 1
          else
            Rails.logger.error "Failed to sync match #{fpl_id}: #{match.errors.full_messages.join(', ')}"
            error_count += 1
          end
        rescue => e
          Rails.logger.error "Exception syncing fixture #{fixture['id']}: #{e.message}"
          error_count += 1
        end
      end

      Rails.logger.info "Match sync results: #{success_count} synced, #{skip_count} skipped, #{error_count} errors"
    end

    def sync_gameweeks(events)
      # Reset all current/next flags before processing
      Gameweek.update_all(is_current: false, is_next: false)

      events.each_with_index do |event, index|
        fpl_id = event["id"]
        name = event["name"]

        # Skip if essential fields are missing
        next if fpl_id.nil? || name.blank? || event["deadline_time"].blank?

        begin
          start_time = Time.parse(event["deadline_time"])
        rescue ArgumentError => e
          Rails.logger.warn "Invalid deadline_time for gameweek #{name}: #{event['deadline_time']}"
          next
        end

        # Calculate end_time by looking at the next event's deadline_time
        end_time = nil
        if index < events.length - 1
          next_deadline = events[index + 1]["deadline_time"]
          if next_deadline.present?
            begin
              end_time = Time.parse(next_deadline) - 1.second
            rescue ArgumentError => e
              Rails.logger.warn "Invalid next deadline_time for end_time calculation: #{next_deadline}"
            end
          end
        end

        # Determine status flags from API
        is_current = event["is_current"] || false
        is_next = event["is_next"] || false
        is_finished = event["finished"] || false

        gameweek_attributes = {
          name: name,
          start_time: start_time,
          end_time: end_time,
          is_current: is_current,
          is_next: is_next,
          is_finished: is_finished
        }

        gameweek = Gameweek.find_or_initialize_by(fpl_id: fpl_id)
        gameweek.assign_attributes(gameweek_attributes)

        if gameweek.save
          Rails.logger.debug "Synced gameweek: #{name} (#{start_time})"
        else
          Rails.logger.warn "Failed to sync gameweek #{name}: #{gameweek.errors.full_messages.join(', ')}"
        end
      end
    end
  end
end
