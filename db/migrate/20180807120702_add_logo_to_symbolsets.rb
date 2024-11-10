class AddLogoToSymbolsets < ActiveRecord::Migration[5.2]
  def change
    add_column :symbolsets, :logo, :string, after: :publisher_url
  end
end
