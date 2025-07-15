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

ActiveRecord::Schema[8.0].define(version: 2025_07_15_211022) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analysis_jobs", force: :cascade do |t|
    t.string "job_type"
    t.string "status"
    t.integer "total_items"
    t.integer "processed_items"
    t.float "progress_percentage"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.text "body", null: false
    t.text "translated_body"
    t.integer "external_id", null: false
    t.string "status", default: "new"
    t.integer "keyword_matches", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_comments_on_external_id", unique: true
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["status"], name: "index_comments_on_status"
  end

  create_table "group_metrics", force: :cascade do |t|
    t.float "avg_score"
    t.float "median_score"
    t.float "std_dev"
    t.integer "total_comments"
    t.integer "approved_comments"
    t.integer "total_users"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "keywords", force: :cascade do |t|
    t.string "word", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active"
    t.index ["word"], name: "index_keywords_on_word", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.integer "external_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_posts_on_external_id", unique: true
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "processed_comments", force: :cascade do |t|
    t.bigint "comment_id", null: false
    t.text "original_text"
    t.text "translated_text"
    t.string "status"
    t.boolean "approved"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id"], name: "index_processed_comments_on_comment_id"
  end

  create_table "user_metrics", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.float "avg_score"
    t.float "median_score"
    t.float "std_dev"
    t.integer "total_comments"
    t.integer "approved_comments"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_metrics_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "name"
    t.string "email"
    t.integer "external_id", null: false
    t.boolean "processed", default: false
    t.json "metrics"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_users_on_external_id", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "comments", "posts"
  add_foreign_key "posts", "users"
  add_foreign_key "processed_comments", "comments"
  add_foreign_key "user_metrics", "users"
end
