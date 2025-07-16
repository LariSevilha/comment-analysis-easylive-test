class CreateProcessingJobs < ActiveRecord::Migration[7.0]
  def change
    create_table :processing_jobs do |t|
      t.string :job_type, null: false
      t.integer :status 
      t.text :progress_info
      t.text :error_message
      t.integer :total_items, default: 0
      t.integer :processed_items, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      
      t.timestamps
    end
    
    add_index :processing_jobs, :job_type
    add_index :processing_jobs, :status
    add_index :processing_jobs, :created_at
  end
end