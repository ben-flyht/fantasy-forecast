class AddTeamIdToPerformances < ActiveRecord::Migration[8.0]
  def change
    # Add column without null constraint first
    add_reference :performances, :team, foreign_key: true

    # Backfill team_id from player's current team
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE performances
          SET team_id = players.team_id
          FROM players
          WHERE performances.player_id = players.id
        SQL
      end
    end

    # Now add the null constraint
    change_column_null :performances, :team_id, false
  end
end
