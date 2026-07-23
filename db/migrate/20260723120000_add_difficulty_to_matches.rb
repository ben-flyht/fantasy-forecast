class AddDifficultyToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :home_difficulty, :integer
    add_column :matches, :away_difficulty, :integer
  end
end
