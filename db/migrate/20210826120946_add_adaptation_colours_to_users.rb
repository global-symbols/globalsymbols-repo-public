class AddAdaptationColoursToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :default_hair_colour, :string, after: :location
    add_column :users, :default_skin_colour, :string, after: :default_hair_colour
  end
end
