class ChangeUploadFieldsOnImage < ActiveRecord::Migration[5.2]
  def change
    rename_column :images, :filename, :imagefile
    remove_column :images, :uri, :string
  end
end
