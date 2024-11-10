class RemoveLanguageFromConcept < ActiveRecord::Migration[5.2]
  def change
    remove_column :concepts, :language, :string, after: :language_id
  end
end
