class AddCanvasToBoardBuilderMedia < ActiveRecord::Migration[6.0]
  def change
    add_column :boardbuilder_media, :canvas, :string, after: :width
  end
end
