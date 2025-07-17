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

ActiveRecord::Schema[7.1].define(version: 2025_07_16_180901) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "comments", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.text "body"
    t.text "translated_body"
    t.string "external_id"
    t.string "status", default: "new"
    t.integer "keyword_count", default: 0
    t.bigint "post_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_comments_on_external_id", unique: true
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["status"], name: "index_comments_on_status"
  end

  create_table "group_metrics", force: :cascade do |t|
    t.integer "total_users", default: 0
    t.integer "total_comments", default: 0
    t.integer "approved_comments", default: 0
    t.integer "rejected_comments", default: 0
    t.decimal "avg_keyword_count", precision: 8, scale: 2, default: "0.0"
    t.decimal "median_keyword_count", precision: 8, scale: 2, default: "0.0"
    t.decimal "std_dev_keyword_count", precision: 8, scale: 2, default: "0.0"
    t.datetime "calculated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "job_trackers", force: :cascade do |t|
    t.string "job_id"
    t.integer "status", default: 0
    t.integer "progress", default: 0
    t.integer "total", default: 0
    t.text "error_message"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_job_trackers_on_job_id", unique: true
    t.index ["status"], name: "index_job_trackers_on_status"
  end

  create_table "keywords", force: :cascade do |t|
    t.string "word"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((word)::text)", name: "index_keywords_on_LOWER_word", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.string "external_id"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_posts_on_external_id", unique: true
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "user_metrics", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "total_comments", default: 0
    t.integer "approved_comments", default: 0
    t.integer "rejected_comments", default: 0
    t.decimal "avg_keyword_count", precision: 8, scale: 2, default: "0.0"
    t.decimal "median_keyword_count", precision: 8, scale: 2, default: "0.0"
    t.decimal "std_dev_keyword_count", precision: 8, scale: 2, default: "0.0"
    t.datetime "calculated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_metrics_on_user_id"
    t.index ["user_id"], name: "index_user_metrics_on_user_id_unique", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["external_id"], name: "index_users_on_external_id", unique: true
  end

  add_foreign_key "comments", "posts"
  add_foreign_key "posts", "users"
  add_foreign_key "user_metrics", "users"
end
