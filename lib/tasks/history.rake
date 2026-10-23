namespace :ff do
  desc "Download past seasons for the backtest into a directory of their own (usage: rake ff:fetch_history[tmp/history])"
  task :fetch_history, [ :dir ] => :environment do |_t, args|
    dir = args[:dir] || Rails.root.join("tmp/history").to_s
    History::Download.call(dir).each { |path| puts "Saved #{path}" }
  end

  desc "Replay ExpectedPoints over past seasons and print the backtest (usage: rake ff:backtest_history[tmp/history])"
  task :backtest_history, [ :dir ] => :environment do |_t, args|
    History::Report.new(args[:dir] || Rails.root.join("tmp/history").to_s).call
  end
end
