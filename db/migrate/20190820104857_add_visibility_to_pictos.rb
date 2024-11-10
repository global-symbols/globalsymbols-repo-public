class AddVisibilityToPictos < ActiveRecord::Migration[5.2]
  def change
    add_column :pictos, :visibility, :integer, after: :publisher_ref, null: false, default: 0
  end
end
