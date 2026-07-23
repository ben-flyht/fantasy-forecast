class AddStrengthToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :strength, :integer
    add_column :teams, :strength_overall_home, :integer
    add_column :teams, :strength_overall_away, :integer
    add_column :teams, :strength_attack_home, :integer
    add_column :teams, :strength_attack_away, :integer
    add_column :teams, :strength_defence_home, :integer
    add_column :teams, :strength_defence_away, :integer
  end
end
