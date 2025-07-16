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

ActiveRecord::Schema[8.0].define(version: 2025_07_15_210519) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analysis_jobs", force: :cascade do |t|
    t.string "job_type", null: false
    t.integer "status"
    t.json "metadata", default: {}
    t.integer "total_items", default: 0
    t.integer "processed_items", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_type"], name: "index_analysis_jobs_on_job_type"
    t.index ["status"], name: "index_analysis_jobs_on_status"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.string "name"
    t.string "email"
    t.text "body", null: false
    t.text "translated_body"
    t.integer "external_id", null: false
    t.integer "status"
    t.datetime "processed"
    t.integer "keyword_matches_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_comments_on_external_id", unique: true
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["processed"], name: "index_comments_on_processed"
    t.index ["status"], name: "index_comments_on_status"
  end

  create_table "group_metrics", force: :cascade do |t|
    t.string "metric_type", null: false
    t.decimal "value", precision: 10, scale: 4, null: false
    t.integer "sample_size", default: 0
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_group_metrics_on_created_at"
    t.index ["metric_type"], name: "index_group_metrics_on_metric_type"
  end

  create_table "keywords", force: :cascade do |t|
    t.string "word", null: false
    t.boolean "active", default: true
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_keywords_on_active"
    t.index ["word"], name: "index_keywords_on_word", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.integer "external_id", null: false
    t.integer "comments_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_posts_on_external_id", unique: true
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "processing_jobs", force: :cascade do |t|
    t.string "job_type", null: false
    t.integer "status"
    t.text "progress_info"
    t.text "error_message"
    t.integer "total_items", default: 0
    t.integer "processed_items", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_processing_jobs_on_created_at"
    t.index ["job_type"], name: "index_processing_jobs_on_job_type"
    t.index ["status"], name: "index_processing_jobs_on_status"
  end

  create_table "user_metrics", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "metric_type", null: false
    t.decimal "value", precision: 10, scale: 4, null: false
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_type"], name: "index_user_metrics_on_metric_type"
    t.index ["user_id", "metric_type"], name: "index_user_metrics_on_user_id_and_metric_type"
    t.index ["user_id"], name: "index_user_metrics_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "name"
    t.string "email"
    t.integer "external_id", null: false
    t.text "address"
    t.text "phone"
    t.text "website"
    t.text "company"
    t.datetime "processed"
    t.integer "approved_comments_count", default: 0
    t.integer "rejected_comments_count", default: 0
    t.integer "total_comments_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_users_on_external_id", unique: true
    t.index ["processed"], name: "index_users_on_processed"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "comments", "posts"
  add_foreign_key "posts", "users"
  add_foreign_key "user_metrics", "users"
end
