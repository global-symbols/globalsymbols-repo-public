class AddLanguageToUser < ActiveRecord::Migration[5.2]
  def change
    add_reference :users, :language, foreign_key: true, after: :id
  end
end
