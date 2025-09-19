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

ActiveRecord::Schema[8.0].define(version: 2025_09_19_180022) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "players", force: :cascade do |t|
    t.string "name", null: false
    t.string "team", null: false
    t.integer "fpl_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "short_name"
    t.string "position", null: false
    t.index ["fpl_id"], name: "index_players_on_fpl_id", unique: true
  end

  create_table "predictions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "player_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "gameweek_id", null: false
    t.string "category", null: false
    t.index ["gameweek_id"], name: "index_predictions_on_gameweek_id"
    t.index ["player_id"], name: "index_predictions_on_player_id"
    t.index ["user_id"], name: "index_predictions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "username", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "predictions", "gameweeks"
  add_foreign_key "predictions", "players"
  add_foreign_key "predictions", "users"
end
