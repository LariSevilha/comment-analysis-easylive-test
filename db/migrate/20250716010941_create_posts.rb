class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.string :title
      t.text :body
      t.string :external_id
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :posts, :external_id, unique: true
  end
end
