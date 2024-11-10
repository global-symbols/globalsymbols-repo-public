class AddDescriptionToBoardbuilderBoards < ActiveRecord::Migration[6.0]
  def change
    add_column :boardbuilder_boards, :description, :string, after: :name
  end
end
