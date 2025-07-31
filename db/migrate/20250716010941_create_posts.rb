class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.string :title
      t.text :body
      t.integer :user_id
      t.string :external_id
      t.timestamps 
      t.index :user_id
    end
  end
end

