class AddFileHashToBoardbuilderMedia < ActiveRecord::Migration[6.1]
  def change
    add_column :boardbuilder_media, :file_hash, :string
  end
end
