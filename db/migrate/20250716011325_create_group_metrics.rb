class CreateGroupMetrics < ActiveRecord::Migration[7.1]
  def change
    create_table :group_metrics do |t|
      t.integer :total_users, default: 0
      t.integer :total_comments, default: 0
      t.integer :approved_comments, default: 0
      t.integer :rejected_comments, default: 0
      t.decimal :avg_keyword_count, precision: 8, scale: 2, default: 0.0
      t.decimal :median_keyword_count, precision: 8, scale: 2, default: 0.0
      t.decimal :std_dev_keyword_count, precision: 8, scale: 2, default: 0.0
      t.datetime :calculated_at

      t.timestamps
    end
  end
end
