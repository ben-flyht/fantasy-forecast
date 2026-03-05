class RemoveExpectedGoalsFromMatches < ActiveRecord::Migration[8.1]
  def change
    remove_column :matches, :home_team_expected_goals, :decimal, precision: 4, scale: 2
    remove_column :matches, :away_team_expected_goals, :decimal, precision: 4, scale: 2
  end
end
