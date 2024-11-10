class AddMediaToBoardBuilderCell < ActiveRecord::Migration[6.0]
  def change
    add_reference :boardbuilder_cells, :boardbuilder_media, null: true, foreign_key: true, after: :picto_id
  end
end
