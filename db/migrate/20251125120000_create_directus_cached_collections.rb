class CreateDirectusCachedCollections < ActiveRecord::Migration[6.1]
  def change
    create_table :directus_cached_collections do |t|
      t.string :name, null: false, index: { unique: true }
      t.boolean :active, default: true, null: false
      t.text :parameter_sets
      t.integer :priority, default: 0, null: false  # For ordering during cache warming
      t.text :description

      t.timestamps
    end

    # Add an index for active collections ordered by priority for efficient queries
    add_index :directus_cached_collections, [:active, :priority], name: 'index_directus_cached_collections_active_priority'
  end
end
