
ActiveRecord::Schema[8.0].define(version: 2025_07_15_210519) do
  enable_extension "pg_catalog.plpgsql"

  create_table "analysis_jobs", force: :cascade do |t|
    t.string "job_type", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "metadata", default: {}
    t.integer "total_items", default: 0
    t.integer "processed_items", default: 0
    t.float "progress_percentage", default: 0.0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_type"], name: "index_analysis_jobs_on_job_type"
    t.index ["metadata"], name: "index_analysis_jobs_on_metadata", using: :gin
    t.index ["status"], name: "index_analysis_jobs_on_status"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "user_id", null: false
    t.string "name"
    t.string "email"
    t.text "body", null: false
    t.text "translated_body"
    t.integer "external_id", null: false
    t.string "status", default: "pending"
    t.datetime "processed"
    t.integer "keyword_matches_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_comments_on_external_id", unique: true
    t.index ["keyword_matches_count"], name: "index_comments_on_keyword_matches_count"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["processed"], name: "index_comments_on_processed"
    t.index ["status"], name: "index_comments_on_status"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "group_metrics", force: :cascade do |t|
    t.jsonb "data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.float "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.integer "comments_count", default: 0
    t.jsonb "analysis_metrics", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_metrics"], name: "index_users_on_analysis_metrics", using: :gin
    t.index ["external_id"], name: "index_users_on_external_id", unique: true
    t.index ["processed"], name: "index_users_on_processed"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "posts", "users"
  add_foreign_key "user_metrics", "users"
end
