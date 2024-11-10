class RemoveLabelFieldsFromPictos < ActiveRecord::Migration[5.2]
  def change
    remove_column :pictos, :language, :string
    remove_column :pictos, :label, :string
    remove_column :pictos, :diacritised_label, :string
    remove_column :pictos, :description, :text
  end
end
