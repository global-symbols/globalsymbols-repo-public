class CreateSources < ActiveRecord::Migration[6.0]
  def change
    # Add the Sources table
    create_table :sources do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :authoritative, null: false
      t.text :description

      t.timestamps
    end

    # Add foreign keys on the tables that will use Sources
    add_reference :pictos, :source, null: true, foreign_key: true, after: :category_id
    add_reference :labels, :source, null: true, foreign_key: true, after: :picto_id

    # If we're migrating up, add options to the Source table and set all Labels/Pictos to the global-symbols Source
    up_only do
      Label.reset_column_information
      Picto.reset_column_information
      Source.reset_column_information

      Source.create(name: 'Publisher API', slug: 'api', authoritative: true)
      Source.create(name: 'Publisher Repository', slug: 'repo', authoritative: true)
      gs = Source.create(name: 'Global Symbols', slug: 'global-symbols', authoritative: true)

      Source.create(name: 'Translation Suggestion', slug: 'translation-suggestion', authoritative: false)

      Source.create(name: 'Public Suggestion', slug: 'public-suggestion', authoritative: false)

      # Update all Labels and Pictos with the GS Source.
      Label.update_all(source_id: gs.id)
      Picto.update_all(source_id: gs.id)
    end

  end
end
