class AddHeaderMediaToBoardbuilderBoards < ActiveRecord::Migration[6.0]
  def change
    add_reference :boardbuilder_boards, :header_boardbuilder_media, null: true, foreign_key: { to_table: :boardbuilder_media }
  end
end
