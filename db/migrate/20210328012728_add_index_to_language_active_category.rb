class AddIndexToLanguageActiveCategory < ActiveRecord::Migration[6.1]
  def change
    add_index :languages, [:active, :category]
  end
end
