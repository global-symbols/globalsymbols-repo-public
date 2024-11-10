class AddAutoUpdateToSymbolsets < ActiveRecord::Migration[6.0]
  def change
    add_column :symbolsets, :auto_update, :boolean, after: :slug
  end
end
