class CreateAnalysisJobs < ActiveRecord::Migration[7.0]
  def change
    create_table :analysis_jobs do |t|
      t.string :job_type, null: false
      t.integer :status, default: 'pending'
      t.json :metadata, default: {}
      t.integer :total_items, default: 0
      t.integer :processed_items, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      
      t.timestamps
    end
    
    add_index :analysis_jobs, :job_type
    add_index :analysis_jobs, :status
  end
end