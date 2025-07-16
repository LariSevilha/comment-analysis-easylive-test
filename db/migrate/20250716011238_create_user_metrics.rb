class CreateUserMetrics < ActiveRecord::Migration[7.1]
  def change
    create_table :user_metrics do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :total_comments, default: 0
      t.integer :approved_comments, default: 0
      t.integer :rejected_comments, default: 0
      t.decimal :avg_keyword_count, precision: 8, scale: 2, default: 0.0
      t.decimal :median_keyword_count, precision: 8, scale: 2, default: 0.0
      t.decimal :std_dev_keyword_count, precision: 8, scale: 2, default: 0.0
      t.datetime :calculated_at

      t.timestamps
    end

    add_index :user_metrics, :user_id, unique: true, name: 'index_user_metrics_on_user_id_unique'
  end
end
