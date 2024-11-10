class AddPublisherRefToPictos < ActiveRecord::Migration[5.2]
  def change
    add_column :pictos, :publisher_ref, :string, after: :description
    rename_column :pictos, :undiacritised_label, :diacritised_label
  end
end
