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

ActiveRecord::Schema[8.0].define(version: 2025_09_22_210735) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "forecasts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "player_id", null: false
    t.bigint "gameweek_id", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gameweek_id"], name: "index_forecasts_on_gameweek_id"
    t.index ["player_id"], name: "index_forecasts_on_player_id"
    t.index ["user_id", "player_id", "gameweek_id"], name: "index_forecasts_on_unique_constraint", unique: true
    t.index ["user_id"], name: "index_forecasts_on_user_id"
  end

  create_table "gameweeks", force: :cascade do |t|
    t.integer "fpl_id", null: false
    t.string "name", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.boolean "is_current", default: false, null: false
    t.boolean "is_next", default: false, null: false
    t.boolean "is_finished", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fpl_id"], name: "index_gameweeks_on_fpl_id", unique: true
  end

  create_table "matches", force: :cascade do |t|
    t.bigint "home_team_id", null: false
    t.bigint "away_team_id", null: false
    t.bigint "gameweek_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "fpl_id"
    t.index ["away_team_id"], name: "index_matches_on_away_team_id"
    t.index ["fpl_id"], name: "index_matches_on_fpl_id", unique: true
    t.index ["gameweek_id"], name: "index_matches_on_gameweek_id"
    t.index ["home_team_id"], name: "index_matches_on_home_team_id"
  end

  create_table "opponents", force: :cascade do |t|
    t.bigint "performance_id", null: false
    t.bigint "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["performance_id"], name: "index_opponents_on_performance_id"
    t.index ["team_id"], name: "index_opponents_on_team_id"
  end

  create_table "performances", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "gameweek_id", null: false
    t.integer "gameweek_score", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gameweek_id"], name: "index_performances_on_gameweek_id"
    t.index ["player_id", "gameweek_id"], name: "index_performances_on_player_id_and_gameweek_id", unique: true
    t.index ["player_id"], name: "index_performances_on_player_id"
  end

  create_table "players", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "position", null: false
    t.string "short_name"
    t.integer "fpl_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "team_id"
    t.index ["fpl_id"], name: "index_players_on_fpl_id", unique: true
    t.index ["team_id"], name: "index_players_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name"
    t.string "short_name"
    t.integer "fpl_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fpl_id"], name: "index_teams_on_fpl_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "username", null: false
    t.string "role", default: "forecaster", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "forecasts", "gameweeks"
  add_foreign_key "forecasts", "players"
  add_foreign_key "forecasts", "users"
  add_foreign_key "matches", "gameweeks"
  add_foreign_key "matches", "teams", column: "away_team_id"
  add_foreign_key "matches", "teams", column: "home_team_id"
  add_foreign_key "opponents", "performances"
  add_foreign_key "opponents", "teams"
  add_foreign_key "performances", "gameweeks"
  add_foreign_key "performances", "players"
  add_foreign_key "players", "teams"
end
