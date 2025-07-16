class CreateGroupMetrics < ActiveRecord::Migration[7.1]
  def change
    create_table :group_metrics do |t|
      t.jsonb :data, default: {}
      t.timestamps
    end
  end
end