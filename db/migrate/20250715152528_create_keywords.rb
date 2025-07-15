class CreateKeywords < ActiveRecord::Migration[7.0]
  def change
    create_table :keywords do |t|
      t.string :word, null: false
      t.boolean :active, default: true 
      t.timestamps
    end
    
    add_index :keywords, :word, unique: true
    add_index :keywords, :active
  end
end