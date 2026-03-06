require "net/http"
require "json"

module Fpl
  class DraftLeagueStatus < ApplicationService
    DRAFT_API_HOST = "draft.premierleague.com"
    CACHE_TTL = 5.minutes
    TIMEOUT = 3

    def initialize(entry_id, league_id, selected_entry_id: nil)
      @entry_id = entry_id.to_i
      @league_id = league_id
      @selected_entry_id = selected_entry_id&.to_i
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        build_player_categories
      end
    end

    def self.lookup_league_id(entry_id)
      uri = URI("https://#{DRAFT_API_HOST}/api/entry/#{entry_id}/public")
      response = make_request(uri)
      return nil unless response&.code == "200"

      data = JSON.parse(response.body)
      data.dig("entry", "league_set")&.first
    rescue StandardError
      nil
    end

    def self.league_info(league_id, my_entry_id)
      Rails.cache.fetch("fpl_draft_league_info:#{league_id}:#{my_entry_id}", expires_in: CACHE_TTL) do
        fetch_league_info(league_id, my_entry_id)
      end
    rescue StandardError
      { mine: nil, opponents: [], next_opponent_id: nil }
    end

    private

    def build_player_categories
      element_status = fetch_element_status
      return nil unless element_status

      draft_id_to_code = fetch_draft_id_to_code
      return nil unless draft_id_to_code

      opponent_entry_id = fetch_opponent_entry_id
      categorize_players(element_status, opponent_entry_id, draft_id_to_code)
    rescue StandardError => e
      Rails.logger.error "FPL Draft API error: #{e.message}"
      nil
    end

    def categorize_players(element_status, opponent_entry_id, draft_id_to_code)
      element_status.each_with_object({}) do |entry, result|
        code = draft_id_to_code[entry["element"]]
        next unless code

        result[code] = player_category(entry, opponent_entry_id)
      end
    end

    def player_category(entry, opponent_entry_id)
      return :available if entry["status"] == "a"
      return :mine if entry["owner"] == @entry_id
      return :opponent if opponent_entry_id && entry["owner"] == opponent_entry_id

      :owned
    end

    def fetch_element_status
      uri = URI("https://#{DRAFT_API_HOST}/api/league/#{@league_id}/element-status")
      response = self.class.make_request(uri)
      return nil unless response&.code == "200"

      JSON.parse(response.body)["element_status"]
    end

    def fetch_draft_id_to_code
      Rails.cache.fetch("fpl_draft_id_to_code", expires_in: 1.day) do
        uri = URI("https://#{DRAFT_API_HOST}/api/bootstrap-static")
        response = self.class.make_request(uri)
        return nil unless response&.code == "200"

        JSON.parse(response.body)["elements"].to_h { |e| [ e["id"], e["code"] ] }
      end
    end

    def fetch_opponent_entry_id
      return @selected_entry_id if @selected_entry_id&.positive?

      data = fetch_league_details
      return nil unless data

      find_opponent_from(data["league_entries"], data["matches"])
    rescue StandardError
      nil
    end

    def fetch_league_details
      uri = URI("https://#{DRAFT_API_HOST}/api/league/#{@league_id}/details")
      response = self.class.make_request(uri)
      return nil unless response&.code == "200"

      JSON.parse(response.body)
    end

    def self.fetch_league_info(league_id, my_entry_id)
      empty = { mine: nil, opponents: [], next_opponent_id: nil }
      data = fetch_league_details(league_id)
      return empty unless data

      entries = data["league_entries"] || []
      my_id = my_entry_id.to_i

      mine = entries.find { |e| e["entry_id"] == my_id }&.dig("entry_name")
      opponents = build_opponents(entries, my_id)
      next_opponent_id = find_next_opponent_id(entries, data["matches"], my_id)

      { mine: mine, opponents: opponents, next_opponent_id: next_opponent_id }
    end

    def self.fetch_league_details(league_id)
      uri = URI("https://#{DRAFT_API_HOST}/api/league/#{league_id}/details")
      response = make_request(uri)
      return nil unless response&.code == "200"

      JSON.parse(response.body)
    end

    def self.build_opponents(entries, my_id)
      entries.filter_map do |e|
        next if e["entry_id"].nil? || e["entry_id"] == my_id
        { id: e["entry_id"], name: e["entry_name"] }
      end.sort_by { |e| e[:name].downcase }
    end

    def self.find_next_opponent_id(entries, matches, my_id)
      my_league_entry_id = entries.find { |e| e["entry_id"] == my_id }&.dig("id")
      return nil unless my_league_entry_id

      next_match = find_next_match(matches, my_league_entry_id)
      return nil unless next_match

      opp_league_id = opponent_from_match(next_match, my_league_entry_id)
      entries.find { |e| e["id"] == opp_league_id }&.dig("entry_id")&.to_s
    end

    def self.find_next_match(matches, my_league_entry_id)
      matches&.find do |m|
        !m["finished"] && (m["league_entry_1"] == my_league_entry_id || m["league_entry_2"] == my_league_entry_id)
      end
    end

    def self.opponent_from_match(match, my_league_entry_id)
      match["league_entry_1"] == my_league_entry_id ? match["league_entry_2"] : match["league_entry_1"]
    end

    def find_opponent_from(league_entries, matches)
      self.class.find_next_opponent_id(league_entries, matches, @entry_id)&.to_i
    end

    def cache_key
      "fpl_draft_status:#{@league_id}:#{@entry_id}:#{@selected_entry_id}"
    end

    def self.make_request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Fantasy Forecast App"
        http.request(request)
      end
    rescue StandardError
      nil
    end
  end
end
