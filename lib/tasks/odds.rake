namespace :odds do
  desc "Sync bookmaker odds from football-data.co.uk (usage: rake odds:sync or odds:sync[2526])"
  task :sync, [ :season ] => :environment do |_t, args|
    result = Odds::SyncFromCsv.call(season: args[:season])
    puts "Odds sync: #{result[:matched]} matched, #{result[:unmatched]} unmatched"
    puts "Error: #{result[:error]}" if result[:error]
  end
end
