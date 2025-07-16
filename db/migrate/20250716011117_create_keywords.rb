class CreateKeywords < ActiveRecord::Migration[7.1]
  def change
    create_table :keywords do |t|
      t.string :word

      t.timestamps
    end

    add_index :keywords, 'LOWER(word)', unique: true
  end
end
