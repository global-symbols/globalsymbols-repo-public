class AddOpenedAtToBoardbuilderBoardSets < ActiveRecord::Migration[6.0]
  def change
    add_column :boardbuilder_board_sets, :opened_at, :datetime, after: :public
  end
end
