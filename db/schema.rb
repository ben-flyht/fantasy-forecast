# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_08_171154) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "forecasts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "gameweek_id", null: false
    t.bigint "player_id", null: false
    t.integer "rank"
    t.decimal "score", precision: 10, scale: 4
    t.bigint "strategy_id"
    t.datetime "updated_at", null: false
    t.index ["gameweek_id", "player_id"], name: "index_forecasts_on_gameweek_id_and_player_id"
    t.index ["gameweek_id"], name: "index_forecasts_on_gameweek_id"
    t.index ["player_id", "gameweek_id"], name: "index_forecasts_on_player_gameweek", unique: true
    t.index ["player_id"], name: "index_forecasts_on_player_id"
    t.index ["strategy_id"], name: "index_forecasts_on_strategy_id"
  end

  create_table "gameweeks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "end_time"
    t.integer "fpl_id", null: false
    t.boolean "is_current", default: false, null: false
    t.boolean "is_finished", default: false, null: false
    t.boolean "is_next", default: false, null: false
    t.string "name", null: false
    t.datetime "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["fpl_id"], name: "index_gameweeks_on_fpl_id", unique: true
  end

  create_table "matches", force: :cascade do |t|
    t.decimal "away_team_expected_goals", precision: 4, scale: 2
    t.bigint "away_team_id", null: false
    t.datetime "created_at", null: false
    t.integer "fpl_id"
    t.bigint "gameweek_id", null: false
    t.decimal "home_team_expected_goals", precision: 4, scale: 2
    t.bigint "home_team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["away_team_id"], name: "index_matches_on_away_team_id"
    t.index ["fpl_id"], name: "index_matches_on_fpl_id", unique: true
    t.index ["gameweek_id", "away_team_id"], name: "index_matches_on_gameweek_id_and_away_team_id"
    t.index ["gameweek_id", "home_team_id"], name: "index_matches_on_gameweek_id_and_home_team_id"
    t.index ["gameweek_id"], name: "index_matches_on_gameweek_id"
    t.index ["home_team_id"], name: "index_matches_on_home_team_id"
  end

  create_table "performances", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "gameweek_id", null: false
    t.integer "gameweek_score", null: false
    t.bigint "player_id", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["gameweek_id", "gameweek_score"], name: "index_performances_on_gameweek_id_and_gameweek_score"
    t.index ["gameweek_id"], name: "index_performances_on_gameweek_id"
    t.index ["player_id", "gameweek_id"], name: "index_performances_on_player_id_and_gameweek_id", unique: true
    t.index ["player_id"], name: "index_performances_on_player_id"
    t.index ["team_id"], name: "index_performances_on_team_id"
  end

  create_table "players", force: :cascade do |t|
    t.integer "code"
    t.datetime "created_at", null: false
    t.string "first_name", null: false
    t.integer "fpl_id", null: false
    t.string "last_name", null: false
    t.string "position", null: false
    t.string "short_name"
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.index ["fpl_id"], name: "index_players_on_fpl_id", unique: true
    t.index ["position", "team_id"], name: "index_players_on_position_and_team_id"
    t.index ["team_id"], name: "index_players_on_team_id"
  end

  create_table "statistics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "gameweek_id", null: false
    t.bigint "player_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 10, scale: 2
    t.index ["gameweek_id", "type"], name: "index_statistics_on_gameweek_type"
    t.index ["gameweek_id"], name: "index_statistics_on_gameweek_id"
    t.index ["player_id", "gameweek_id", "type"], name: "index_statistics_on_player_gameweek_type", unique: true
    t.index ["player_id", "type"], name: "index_statistics_on_player_type"
    t.index ["player_id"], name: "index_statistics_on_player_id"
  end

  create_table "strategies", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "position"
    t.jsonb "strategy_config", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_strategies_on_active"
  end

  create_table "teams", force: :cascade do |t|
    t.integer "code"
    t.datetime "created_at", null: false
    t.integer "fpl_id"
    t.string "name"
    t.string "short_name"
    t.datetime "updated_at", null: false
    t.index ["fpl_id"], name: "index_teams_on_fpl_id", unique: true
  end

  add_foreign_key "forecasts", "gameweeks"
  add_foreign_key "forecasts", "players"
  add_foreign_key "forecasts", "strategies"
  add_foreign_key "matches", "gameweeks"
  add_foreign_key "matches", "teams", column: "away_team_id"
  add_foreign_key "matches", "teams", column: "home_team_id"
  add_foreign_key "performances", "gameweeks"
  add_foreign_key "performances", "players"
  add_foreign_key "performances", "teams"
  add_foreign_key "players", "teams"
  add_foreign_key "statistics", "gameweeks"
  add_foreign_key "statistics", "players"
end
