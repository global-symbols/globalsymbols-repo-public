class AddOriginalFilenameToImages < ActiveRecord::Migration[6.1]
  def change
    add_column :images, :original_filename, :string
  end
end
