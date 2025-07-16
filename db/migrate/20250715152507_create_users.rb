class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :name
      t.string :email
      t.integer :external_id, null: false
      t.text :address
      t.text :phone
      t.text :website
      t.text :company
      t.datetime :processed
      t.integer :approved_comments_count, default: 0
      t.integer :rejected_comments_count, default: 0
      t.integer :comments_count, default: 0
      t.jsonb :analysis_metrics, default: {}

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :external_id, unique: true
    add_index :users, :processed
    add_index :users, :analysis_metrics, using: :gin
  end
end
