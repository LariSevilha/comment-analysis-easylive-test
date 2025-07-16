class CreateGroupMetrics < ActiveRecord::Migration[7.0]
  def change
    create_table :group_metrics do |t|
      t.string :metric_type, null: false
      t.decimal :value, precision: 10, scale: 4, null: false
      t.integer :sample_size, default: 0
      t.text :metadata
      
      t.timestamps
    end
    
    add_index :group_metrics, :metric_type
    add_index :group_metrics, :created_at
  end
end