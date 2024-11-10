class AddPulledAtToSymbolsets < ActiveRecord::Migration[6.1]
  def change
    add_column :symbolsets, :pulled_at, :datetime, after: :featured_level
  end
end
