class AddCategoryToPicto < ActiveRecord::Migration[5.2]
  def change
    add_reference :pictos, :category, foreign_key: true, after: :id
  end
end
