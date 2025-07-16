class CreateComments < ActiveRecord::Migration[7.1]
  def change
    create_table :comments do |t|
      t.string :name
      t.string :email
      t.text :body
      t.text :translated_body
      t.string :external_id
      t.string :status, default: 'new'
      t.integer :keyword_count, default: 0
      t.references :post, null: false, foreign_key: true

      t.timestamps
    end

    add_index :comments, :external_id, unique: true
    add_index :comments, :status
  end
end
