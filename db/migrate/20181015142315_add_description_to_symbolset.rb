class AddDescriptionToSymbolset < ActiveRecord::Migration[5.2]
  def change
    add_column :symbolsets, :description, :string, after: :name
  end
end
