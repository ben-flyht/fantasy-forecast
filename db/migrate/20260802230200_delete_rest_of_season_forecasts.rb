# The season horizon was renamed and its rows renamed with it, but checkouts that
# predate the rename went on writing the old name, so a second set of the same 564
# forecasts came back under a horizon nothing reads. Every one has a season row for
# the same player and gameweek, so there is nothing here to keep.
#
# The settings behind them go too, on the same terms as the migration before this
# one: a set of parameters no forecast points at says nothing about any forecast we
# hold.
class DeleteRestOfSeasonForecasts < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM forecasts WHERE horizon = 'rest_of_season'"

    execute <<~SQL
      DELETE FROM strategies
      WHERE NOT EXISTS (
        SELECT 1 FROM forecasts WHERE forecasts.strategy_id = strategies.id
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
