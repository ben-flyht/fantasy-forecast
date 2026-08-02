# Settings nothing was ever forecast with: the old positional bots, and every set
# left behind when a re-run of the same gameweek repointed its forecasts at the
# settings that replaced them. They say nothing about any forecast we hold, so
# they are noise in the only question this table exists to answer.
class DeleteStrategiesWithoutForecasts < ActiveRecord::Migration[8.1]
  def up
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
