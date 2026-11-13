class AddResultsToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :kickoff_at, :datetime
    add_column :matches, :home_score, :integer
    add_column :matches, :away_score, :integer
    add_column :matches, :started, :boolean, default: false, null: false
    add_column :matches, :finished_provisional, :boolean, default: false, null: false
    add_index :matches, :kickoff_at

    reversible do |direction|
      direction.up { backfill }
    end
  end

  private

  def backfill
    execute <<~SQL.squish
      UPDATE matches SET
        kickoff_at = (latest.data->>'kickoff_time')::timestamptz,
        home_score = (latest.data->>'team_h_score')::integer,
        away_score = (latest.data->>'team_a_score')::integer,
        started = COALESCE((latest.data->>'started')::boolean, FALSE),
        finished_provisional = COALESCE((latest.data->>'finished_provisional')::boolean, FALSE),
        finished = COALESCE((latest.data->>'finished')::boolean, matches.finished)
      FROM (
        SELECT DISTINCT ON (fpl_id) fpl_id, data FROM payloads
        WHERE kind = 'fixture' ORDER BY fpl_id, updated_at DESC
      ) AS latest
      WHERE latest.fpl_id = matches.fpl_id
    SQL
  end
end
