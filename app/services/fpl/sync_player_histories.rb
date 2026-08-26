module Fpl
  # Last season's totals for every player, from FPL's per-player summary endpoint.
  #
  # Before a ball is kicked FPL zeroes the season stats in bootstrap-static, so
  # the concepts that lean on recent scoring have nothing to read. Last season's
  # totals are the best cold-start stand-in and they live only on this endpoint,
  # one request per player.
  #
  # That makes this the most expensive sync we run, so it is deliberately
  # incremental: players whose totals are already stored are skipped. A re-run
  # costs almost nothing and an interrupted run picks up where it stopped.
  class SyncPlayerHistories < ApplicationService
    # The key in FPL's past-season entry => the statistic type we store it as.
    #
    # Read this way round to match Fpl::SyncPlayers::SNAPSHOT_STATS. The two used
    # to disagree, and a mapping whose direction you have to work out from the
    # block that walks it is a mapping that gets read backwards.
    # Assists are a total rather than a rate, like the bonus beside them, because
    # that is how the forecast reads them and because a season's assists survive a
    # column of two decimal places where a rate of 0.08 a game does not.
    STAT_TYPES = {
      "total_points" => "last_season_points",
      "minutes" => "last_season_minutes",
      "bonus" => "last_season_bonus",
      "assists" => "last_season_assists"
    }.freeze

    # The same per-90 rates bootstrap publishes for the current season, worked out
    # from the season's totals so a forecast can read either interchangeably.
    # Without these, a player's minutes come from last season while his scoring
    # rate comes from a season he may not have played in.
    # What actually happened sits alongside what was expected to, because the two
    # disagree and we have no way of knowing by how much without holding both.
    #
    # The forecast prices a goal from expected goals and an assist from expected
    # assists, then reads a clean sheet, a save and a bonus point straight off what
    # a player really did. Mixing the two is only safe if expected and actual come
    # out level, and on assists they do not come close: FPL pays for winning a
    # penalty, for a deflection and for a rebound, none of which the expected figure
    # counts. Nothing here changes what the forecast reads. It stores the other half
    # of each pair so the gap can be measured rather than argued about.
    RATE_TYPES = {
      "expected_goals" => "last_season_expected_goals_per_90",
      "expected_goal_involvements" => "last_season_expected_goal_involvements_per_90",
      "expected_assists" => "last_season_expected_assists_per_90",
      "goals_scored" => "last_season_goals_per_90",
      "clean_sheets" => "last_season_clean_sheets_per_90",
      "saves" => "last_season_saves_per_90",
      "expected_goals_conceded" => "last_season_expected_goals_conceded_per_90",
      "goals_conceded" => "last_season_goals_conceded_per_90",
      "defensive_contribution" => "last_season_defensive_contribution_per_90"
    }.freeze

    # Which season counts as last season, and nothing else does.
    #
    # FPL only lists the seasons a player spent in this division, so the most
    # recent entry is not necessarily the most recent season: a man promoted with
    # Hull last played here in 2020/21, and one at Coventry in 2015/16. Read as
    # last season's, an old campaign makes a nailed-on starter of a player nobody
    # has seen in this league for six years, and a clean sheet rate of one out of
    # a single match played eleven years ago.
    #
    # A season runs August to May, so a date in the second half of the year
    # belongs to the campaign starting that year and anything earlier to the one
    # before it. Taken from the gameweek being synced rather than from today, so
    # the answer is the same whenever it is asked.
    SEASON_STARTS = 7

    MINUTES_IN_A_MATCH = 90.0

    # What we currently record from a past season. Bump it when that set changes
    # and every player is asked again on the next run, rather than being left with
    # a partial history that nothing notices.
    RECORD_VERSION = 6.0

    REQUEST_DELAY = 0.5 # seconds between requests, to stay a polite guest

    # Written this often, so an interrupted run keeps what it had.
    BATCH = 25

    # How long a single run may take before it stops and leaves the rest to the
    # next one. Comfortably inside an hourly slot, whatever the platform allows.
    TIME_BUDGET = 3.minutes

    # Recorded for a player FPL has no past seasons for, so he is not asked about
    # again. Nothing reads it: it is a receipt, not a statistic.
    CHECKED = "history_checked".freeze

    def initialize(delay: REQUEST_DELAY, budget: TIME_BUDGET, api: Api.new)
      @delay = delay
      @budget = budget
      @api = api
    end

    def call
      gameweek = snapshot_gameweek
      return log_no_gameweek unless gameweek

      players = players_missing_history(gameweek)
      return log_nothing_to_do if players.empty?

      sync_players(players, gameweek)
    rescue => e
      Rails.logger.error "FPL player history sync failed: #{e.message}"
      false
    end

    private

    # Pre-season there is no current gameweek, but last season's totals are
    # exactly what the upcoming one needs, so attach them there.
    def snapshot_gameweek
      Gameweek.current_gameweek || Gameweek.next_gameweek
    end

    def players_missing_history(gameweek)
      asked = Statistic.where(gameweek: gameweek, type: CHECKED, value: RECORD_VERSION).select(:player_id)
      Player.where.not(id: asked).to_a
    end

    def sync_players(players, gameweek)
      Rails.logger.info "Syncing last-season history for #{players.size} players..."
      done = collect_in_batches(players, gameweek)
      Rails.logger.info "Synced #{done} of #{players.size} players; #{players.size - done} left for the next run"
      true
    end

    # Saves as it goes and stops when its time is up, so whatever it managed is
    # kept and the next run continues from there.
    def collect_in_batches(players, gameweek)
      deadline = Time.current + @budget
      done = 0

      players.each_slice(BATCH) do |batch|
        done += collect(batch, gameweek, deadline)
        break if Time.current > deadline
      end
      done
    end

    # Stops the moment its time is up, mid-batch if it must, and keeps what it
    # has: one slow answer should not cost the batch, nor the batch the hour.
    def collect(batch, gameweek, deadline)
      records = []
      done = 0

      batch.each do |player|
        records.concat(player_records(player, gameweek))
        done += 1
        break if Time.current > deadline
      end
      Statistic.store(records)
      done
    end

    def player_records(player, gameweek)
      sleep(@delay) if @delay.positive?
      summary = @api.summary(player.fpl_id)
      # Nobody answered, which is not the same as an answer of none. Left
      # unreceipted so the next run asks again rather than recording a silence.
      return [] if summary.nil?

      season = last_season_in(summary, gameweek)
      return nothing_worth_keeping(player, gameweek) if season.nil?

      now = Time.current
      totals(player, gameweek, season, now) +
        rates(player, gameweek, season, now) + [ checked_record(player, gameweek, now) ]
    end

    # No season of his that we would read, so whatever we hold from an older one
    # goes, and a receipt is left so he is not asked again every hour.
    def nothing_worth_keeping(player, gameweek)
      forget_old_seasons(player, gameweek)
      [ checked_record(player, gameweek, Time.current) ]
    end

    # A receipt that we asked, so a player with no past is not asked about again.
    def checked_record(player, gameweek, now)
      record(player, gameweek, CHECKED, RECORD_VERSION, now)
    end

    def totals(player, gameweek, season, now)
      STAT_TYPES.filter_map do |key, type|
        value = season[key]
        next if value.nil?

        record(player, gameweek, type, value.to_f, now)
      end
    end

    # A rate needs football to have happened. Nought minutes leaves them unwritten
    # rather than stored as zeroes, so a player with no past reads as unknown.
    def rates(player, gameweek, season, now)
      nineties = season["minutes"].to_f / MINUTES_IN_A_MATCH
      return [] unless nineties.positive?

      RATE_TYPES.filter_map do |key, type|
        value = season[key]
        next if value.nil?

        record(player, gameweek, type, value.to_f / nineties, now)
      end
    end

    def record(player, gameweek, type, value, now)
      { player_id: player.id, gameweek_id: gameweek.id, type: type,
        value: value, created_at: now, updated_at: now }
    end

    # history_past runs oldest first, so the most recent season is last. It is
    # only last season's if it says so. See SEASON_STARTS.
    def last_season_in(summary, gameweek)
      season = summary["history_past"]&.last
      return nil unless season && season["season_name"] == last_season_name(gameweek)

      season
    end

    def last_season_name(gameweek)
      played = gameweek.start_time
      current = played.month < SEASON_STARTS ? played.year - 1 : played.year
      "#{current - 1}/#{format('%02d', current % 100)}"
    end

    # A record we have decided not to trust has to go, or the campaign this run
    # rejected stays in circulation and the forecast keeps reading it.
    def forget_old_seasons(player, gameweek)
      Statistic.where(player_id: player.id, gameweek_id: gameweek.id, type: season_types).delete_all
    end

    # The types we store a past season under, which is the far side of both
    # mappings above.
    def season_types
      @season_types ||= STAT_TYPES.values + RATE_TYPES.values
    end

    def log_nothing_to_do
      Rails.logger.info "No players need a last-season history sync."
      true
    end

    # Nowhere yet to file last season's totals. A state, not a fault.
    def log_no_gameweek
      Rails.logger.info "No gameweek to attach last-season history to, skipping."
      true
    end
  end
end
