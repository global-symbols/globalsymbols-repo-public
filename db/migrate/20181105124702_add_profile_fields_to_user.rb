class AddProfileFieldsToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :prename, :string, after: :role
    add_column :users, :surname, :string, after: :prename
    add_column :users, :company, :string, after: :surname
    add_column :users, :location, :string, after: :company
  end
end
