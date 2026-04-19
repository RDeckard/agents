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

ActiveRecord::Schema[8.1].define(version: 2026_04_19_182557) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "reports", force: :cascade do |t|
    t.string "anthropic_file_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.string "filename"
    t.bigint "session_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["anthropic_file_id"], name: "index_reports_on_anthropic_file_id", unique: true
    t.index ["session_id"], name: "index_reports_on_session_id"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.string "anthropic_session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "crypted_password"
    t.string "email", null: false
    t.string "name"
    t.string "salt"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "reports", "sessions"
  add_foreign_key "reports", "users"
  add_foreign_key "sessions", "users"
end
