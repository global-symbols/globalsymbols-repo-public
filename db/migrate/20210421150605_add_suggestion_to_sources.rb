class AddSuggestionToSources < ActiveRecord::Migration[6.1]
  def change
    add_column :sources, :suggestion, :boolean, after: :authoritative, null: false, default: false
  end
end
