class AddIndexToPictoArchived < ActiveRecord::Migration[6.1]
  def change
    add_index :pictos, :archived
    add_index :pictos, :visibility
    add_index :pictos, [:symbolset_id, :archived]
  end
end
