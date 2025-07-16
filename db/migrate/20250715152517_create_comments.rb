class CreateComments < ActiveRecord::Migration[7.0]
  def change
    create_table :comments do |t|
      t.references :post, null: false, foreign_key: true
      t.string :name
      t.string :email
      t.text :body, null: false
      t.text :translated_body
      t.integer :external_id, null: false
      t.integer :status, default: 'new'
      t.datetime :processed
      t.integer :keyword_matches_count, default: 0
      
      t.timestamps
    end
    
    add_index :comments, :external_id, unique: true
    add_index :comments, :status
    add_index :comments, :processed
  end
end