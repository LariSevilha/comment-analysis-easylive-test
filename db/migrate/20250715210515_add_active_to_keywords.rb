class AddActiveToKeywords < ActiveRecord::Migration[8.0]
  def change
    add_column :keywords, :active, :boolean
  end
end
