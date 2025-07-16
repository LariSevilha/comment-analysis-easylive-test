class CreateUserMetrics < ActiveRecord::Migration[7.1]
  def change
    create_table :user_metrics do |t|
      t.references :user, null: false, foreign_key: true
      t.string :metric_type, null: false
      t.float :value, null: false
      t.timestamps
    end
  end
end