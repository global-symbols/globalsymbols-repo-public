class AddIndexToLanguagesNameAndIso6391 < ActiveRecord::Migration[6.1]
  def change
    add_index :languages, :name
    add_index :languages, :iso639_1
  end
end
