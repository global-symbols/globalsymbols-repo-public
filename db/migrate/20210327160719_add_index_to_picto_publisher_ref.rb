class AddIndexToPictoPublisherRef < ActiveRecord::Migration[6.1]
  def change
    add_index :pictos, [:symbolset_id, :publisher_ref]
  end
end
