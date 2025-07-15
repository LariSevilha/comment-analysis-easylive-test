class CreateAnalysisJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :analysis_jobs do |t|
      t.string :job_type
      t.string :status
      t.integer :total_items
      t.integer :processed_items
      t.float :progress_percentage
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.jsonb :metadata

      t.timestamps
    end
  end
end
