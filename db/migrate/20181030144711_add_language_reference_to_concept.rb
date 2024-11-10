class AddLanguageReferenceToConcept < ActiveRecord::Migration[5.2]
  def change
    add_reference :concepts, :language, foreign_key: true, after: :coding_framework_id
  end
end
