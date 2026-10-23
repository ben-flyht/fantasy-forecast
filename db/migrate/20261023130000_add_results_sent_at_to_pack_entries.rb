class AddResultsSentAtToPackEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :pack_entries, :results_sent_at, :datetime
    add_column :pack_entries, :real_points, :integer
    add_column :pack_entries, :accuracy, :float
    add_column :pack_entries, :forecast_accuracy, :float
  end
end
