class CreateBoardbuilderMedia < ActiveRecord::Migration[6.0]
  def change
    create_table :boardbuilder_media do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :file
      t.string  :format, null: false
      t.integer :filesize, null: false
      t.string :caption
      t.integer :height
      t.integer :width

      t.timestamps
    end
  end
end
