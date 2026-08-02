class RenameRestOfSeasonHorizonToSeason < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE forecasts SET horizon = 'season' WHERE horizon = 'rest_of_season'"
  end

  def down
    execute "UPDATE forecasts SET horizon = 'rest_of_season' WHERE horizon = 'season'"
  end
end
