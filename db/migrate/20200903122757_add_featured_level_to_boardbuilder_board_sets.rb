class AddFeaturedLevelToBoardbuilderBoardSets < ActiveRecord::Migration[6.0]
  def change
    add_column :boardbuilder_board_sets, :featured_level, :integer, after: :public
  end
end
