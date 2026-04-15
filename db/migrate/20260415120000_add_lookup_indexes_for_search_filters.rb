class AddLookupIndexesForSearchFilters < ActiveRecord::Migration[6.1]
  def change
    add_index :symbolsets, :slug unless index_exists?(:symbolsets, :slug)
    add_index :languages, :iso639_2b unless index_exists?(:languages, :iso639_2b)
    add_index :languages, :iso639_2t unless index_exists?(:languages, :iso639_2t)
  end
end
