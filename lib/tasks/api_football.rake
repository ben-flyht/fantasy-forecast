namespace :api_football do
  desc "Sync team IDs from API-Football (one-time setup)"
  task sync_teams: :environment do
    puts "Syncing API-Football team IDs..."

    if ApiFootball::SyncTeams.call
      synced = Team.where.not(api_football_id: nil).count
      puts "Successfully synced #{synced}/#{Team.count} teams"
    else
      puts "Sync failed. Check logs for details."
      exit 1
    end
  end

  desc "Sync expected goals for upcoming gameweek"
  task sync_expected_goals: :environment do
    puts "Syncing API-Football expected goals..."

    gameweek = Gameweek.next_gameweek || Gameweek.current_gameweek
    unless gameweek
      puts "No upcoming gameweek found"
      exit 1
    end

    puts "Target gameweek: #{gameweek.name}"

    if ApiFootball::SyncExpectedGoals.call(gameweek: gameweek)
      synced = Match.where(gameweek: gameweek).with_expected_goals.count
      total = Match.where(gameweek: gameweek).count
      puts "Successfully synced #{synced}/#{total} matches"
    else
      puts "Sync failed. Check logs for details."
      exit 1
    end
  end
end
