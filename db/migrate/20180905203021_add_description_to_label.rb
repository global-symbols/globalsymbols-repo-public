class AddDescriptionToLabel < ActiveRecord::Migration[5.2]
  def change
    add_column :labels, :description, :text, after: :text_diacritised
  end
end
