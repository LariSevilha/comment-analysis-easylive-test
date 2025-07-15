class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :name
      t.string :email
      t.json :analysis_metrics, default: {}
      t.datetime :last_analyzed_at
      t.integer :total_comments, default: 0
      t.integer :approved_comments, default: 0
      t.integer :rejected_comments, default: 0
      
      t.timestamps
    end
    
    add_index :users, :username, unique: true
  end
end