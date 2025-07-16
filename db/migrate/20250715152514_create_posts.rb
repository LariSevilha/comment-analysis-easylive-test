class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false
      t.integer :external_id, null: false
      t.integer :comments_count, default: 0
      
      t.timestamps
    end
    
    add_index :posts, :external_id, unique: true
  end
end