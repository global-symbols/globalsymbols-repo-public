class AddPropertiesToBoardSets < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:boardbuilder_board_sets, :download_count)
        add_column :boardbuilder_board_sets, :download_count, :integer, default: 0
    end
    unless column_exists?(:boardbuilder_board_sets, :description)
        add_column :boardbuilder_board_sets, :description, :text, limit: 1000
    end
    add_column :boardbuilder_board_sets, :tags, :text
    add_column :boardbuilder_board_sets, :lang, :string
    add_column :boardbuilder_board_sets, :author, :string
    add_column :boardbuilder_board_sets, :author_url, :string
    add_column :boardbuilder_board_sets, :self_contained, :boolean, default: false
    add_column :boardbuilder_board_sets, :thumbnail_id, :bigint
    add_foreign_key :boardbuilder_board_sets, :boardbuilder_media, column: :thumbnail_id
  end
end
