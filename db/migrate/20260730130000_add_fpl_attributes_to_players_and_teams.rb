# Facts FPL publishes about a player or a club rather than measurements of a
# gameweek. They belong on the record they describe, not in the statistics table:
# they are text, dates and categories, and they do not change with the week.
class AddFplAttributesToPlayersAndTeams < ActiveRecord::Migration[8.0]
  def change
    # a = available, d = doubtful, i = injured, s = suspended, u = unavailable.
    add_column :players, :status, :string
    add_column :players, :news_added, :datetime
    add_column :players, :birth_date, :date
    add_column :players, :region, :integer      # nationality, for international absences
    add_column :players, :team_join_date, :date # a new signing has no record at this club
    add_column :players, :squad_number, :integer
    add_column :players, :selectable, :boolean, default: true, null: false
    add_column :players, :departed, :boolean, default: false, null: false

    add_index :players, :status

    # The league table, which says more about a club than a difficulty rating does.
    add_column :teams, :played, :integer
    add_column :teams, :win, :integer
    add_column :teams, :draw, :integer
    add_column :teams, :loss, :integer
    add_column :teams, :points, :integer
    add_column :teams, :league_position, :integer
    add_column :teams, :form, :string
    add_column :teams, :unavailable, :boolean, default: false, null: false
  end
end
