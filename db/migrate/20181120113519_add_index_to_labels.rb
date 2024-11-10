class AddIndexToLabels < ActiveRecord::Migration[5.2]
  def change
    add_index :labels, :text
    add_index :labels, :text_diacritised
  end
end
