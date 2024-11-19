class AddPropertiesToBoardSets < ActiveRecord::Migration[6.1]
  def change
    add_column :boardbuilder_board_sets, :download_count, :integer, default: 0
    add_column :boardbuilder_board_sets, :description, :text, limit: 1000
    add_column :boardbuilder_board_sets, :tags, :json
    add_column :boardbuilder_board_sets, :lang, :string
    add_column :boardbuilder_board_sets, :author, :string
    add_column :boardbuilder_board_sets, :author_url, :string
    add_column :boardbuilder_board_sets, :self_contained, :boolean, default: false
    add_column :boardbuilder_board_sets, :thumbnail_id, :bigint
    add_foreign_key :boardbuilder_board_sets, :boardbuilder_media, column: :thumbnail_id
  end
end
