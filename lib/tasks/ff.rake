namespace :ff do
  desc "Scheduled hourly pipeline: detect season change, sync FPL data + odds, regenerate forecasts (idempotent)"
  task hourly: :environment do
    Fpl::HourlyPipeline.call
    puts "Hourly pipeline complete."
  end

  desc "Generate forecasts for the next gameweek"
  task generate: :environment do
    gameweek = Gameweek.next_gameweek

    unless gameweek
      puts "No next gameweek available"
      exit
    end

    puts "Forecasting Gameweek #{gameweek.fpl_id}..."
    count = WeeklyForecast.call(gameweek: gameweek)
    abort "\nForecast failed. Check the logs." unless count

    puts "#{count} players forecast"
  end

  desc "Mark a finished gameweek's forecast against what happened (usage: rake ff:accuracy[12])"
  task :accuracy, [ :gameweek ] => :environment do |_t, args|
    gameweek = args[:gameweek] ? Gameweek.find_by(fpl_id: args[:gameweek].to_i) : Gameweek.finished.ordered.last
    abort "No finished gameweek to mark" unless gameweek

    result = ForecastAccuracy.call(gameweek: gameweek)
    abort "Gameweek #{gameweek.fpl_id} is not finished" unless result

    puts "Gameweek #{gameweek.fpl_id}: how many of the available points our top 10 captured"
    puts format("  %-12s %8s %8s | %8s %8s %8s %8s", "position", "ours", "rho", "fpl", "crowd", "last wk", "average")
    result.each do |position, scores|
      b = scores[:baselines]
      puts format("  %-12s %7.1f%% %8s | %7.1f%% %7.1f%% %7.1f%% %7.1f%%",
                  position, scores[:capture_rate], scores[:correlation] || "-",
                  b[:fpl], b[:crowd], b[:last_week], b[:average])
    end
    beaten = result.count { |_, s| s[:capture_rate] > s[:baselines][:fpl] }
    puts "\nBeat FPL's own expectation in #{beaten} of #{result.size} positions."
  end
end
