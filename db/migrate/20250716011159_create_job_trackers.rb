class CreateJobTrackers < ActiveRecord::Migration[7.1]
  def change
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
  end
end
