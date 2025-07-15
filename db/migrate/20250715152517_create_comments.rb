class CreateComments < ActiveRecord::Migration[7.0]
  def change
    create_table :comments do |t|
      t.references :post, null: false, foreign_key: true
      t.string :name
      t.string :email
      t.text :body
      t.text :translated_body
      t.string :status, default: 'novo'
      t.integer :external_id
      t.integer :matched_keywords_count, default: 0
      t.json :matched_keywords, default: []
      
      t.timestamps
    end
    
    add_index :comments, :external_id, unique: true
    add_index :comments, :status
  end
end