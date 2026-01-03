namespace :the_odds_api do
  desc "Sync expected goals from Pinnacle odds via The Odds API"
  task sync_expected_goals: :environment do
    puts "Syncing expected goals from The Odds API (Pinnacle)..."

    gameweek = Gameweek.next_gameweek || Gameweek.current_gameweek
    unless gameweek
      puts "No upcoming gameweek found"
      exit 1
    end

    puts "Target gameweek: #{gameweek.name}"

    if TheOddsApi::SyncExpectedGoals.call(gameweek: gameweek)
      synced = Match.where(gameweek: gameweek).with_expected_goals.count
      total = Match.where(gameweek: gameweek).count
      puts "Successfully synced #{synced}/#{total} matches"
    else
      puts "Sync failed. Check logs for details."
      exit 1
    end
  end

  desc "Test The Odds API connection and show available events"
  task test: :environment do
    puts "Testing The Odds API connection..."

    client = TheOddsApi::Client.new
    events = client.events

    puts "Found #{events.size} EPL events:"
    events.each do |event|
      puts "  #{event['home_team']} vs #{event['away_team']} (#{event['commence_time']})"
    end

    puts "\nAPI quota: #{client.remaining_requests} requests remaining"
  rescue TheOddsApi::Client::Error => e
    puts "Error: #{e.message}"
    exit 1
  end
end
