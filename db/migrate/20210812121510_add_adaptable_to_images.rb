class AddAdaptableToImages < ActiveRecord::Migration[6.1]
  def change
    add_column :images, :adaptable, :boolean, after: :picto_id, null: false, default: false
  end
end
