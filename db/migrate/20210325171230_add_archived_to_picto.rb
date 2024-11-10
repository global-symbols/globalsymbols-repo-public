class AddArchivedToPicto < ActiveRecord::Migration[6.1]
  def change
    add_column :pictos, :archived, :boolean, after: :publisher_ref, default: 0, null: false
  end
end
