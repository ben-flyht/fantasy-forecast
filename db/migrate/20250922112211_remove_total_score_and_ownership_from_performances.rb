class RemoveTotalScoreAndOwnershipFromPerformances < ActiveRecord::Migration[8.0]
  def change
    remove_column :performances, :total_score, :integer
    remove_column :performances, :ownership_percentage, :decimal
  end
end
