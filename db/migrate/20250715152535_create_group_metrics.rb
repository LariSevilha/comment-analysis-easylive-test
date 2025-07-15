class CreateGroupMetrics < ActiveRecord::Migration[7.0]
  def change
    create_table :group_metrics do |t|
      t.json :metrics_data, default: {}
      t.integer :total_users, default: 0
      t.datetime :calculated_at
      
      t.timestamps
    end
  end
end