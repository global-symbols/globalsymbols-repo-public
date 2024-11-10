class AddFeaturedLevelToSymbolsets < ActiveRecord::Migration[6.0]
  def change
    add_column :symbolsets, :featured_level, :integer, after: :slug
  end
end
