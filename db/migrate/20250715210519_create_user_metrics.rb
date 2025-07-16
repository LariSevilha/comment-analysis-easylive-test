class CreateUserMetrics < ActiveRecord::Migration[7.0]
    def change
      create_table :user_metrics do |t|
        t.references :user, null: false, foreign_key: true
        t.string :metric_type, null: false
        t.decimal :value, precision: 10, scale: 4, null: false
        t.text :metadata
        
        t.timestamps
      end
      
      add_index :user_metrics, [:user_id, :metric_type]
      add_index :user_metrics, :metric_type
    end
  end