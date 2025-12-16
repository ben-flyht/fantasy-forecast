class AddExpectedGoalsToMatches < ActiveRecord::Migration[8.0]
  def change
    add_column :matches, :home_team_expected_goals, :decimal, precision: 4, scale: 2
    add_column :matches, :away_team_expected_goals, :decimal, precision: 4, scale: 2
  end
end
