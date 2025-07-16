class CreateJobTrackers < ActiveRecord::Migration[7.1]
  def change
    create_table :job_trackers do |t|
      t.string :job_id
      t.integer :status, default: 0
      t.integer :progress, default: 0
      t.integer :total, default: 0
      t.text :error_message
      t.json :metadata

      t.timestamps
    end

    add_index :job_trackers, :job_id, unique: true
    add_index :job_trackers, :status
  end
end
