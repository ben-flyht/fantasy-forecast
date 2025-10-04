class RenameContrarianBonusToDifferentialScore < ActiveRecord::Migration[8.0]
  def change
    rename_column :forecasts, :contrarian_bonus, :differential_score
  end
end
