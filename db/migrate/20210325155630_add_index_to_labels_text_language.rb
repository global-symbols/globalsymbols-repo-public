class AddIndexToLabelsTextLanguage < ActiveRecord::Migration[6.1]
  def change
    add_index :labels, [:language_id, :text]
  end
end
