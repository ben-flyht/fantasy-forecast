class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Composite indexes for common queries
    add_index :forecasts, [ :gameweek_id, :player_id ] unless index_exists?(:forecasts, [ :gameweek_id, :player_id ])
    add_index :forecasts, [ :user_id, :gameweek_id ] unless index_exists?(:forecasts, [ :user_id, :gameweek_id ])
    add_index :performances, [ :gameweek_id, :gameweek_score ] unless index_exists?(:performances, [ :gameweek_id, :gameweek_score ])
    add_index :players, [ :position, :team_id ] unless index_exists?(:players, [ :position, :team_id ])
    add_index :matches, [ :gameweek_id, :home_team_id ] unless index_exists?(:matches, [ :gameweek_id, :home_team_id ])
    add_index :matches, [ :gameweek_id, :away_team_id ] unless index_exists?(:matches, [ :gameweek_id, :away_team_id ])
  end
end
