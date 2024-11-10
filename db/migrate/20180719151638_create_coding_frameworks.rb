class CreateCodingFrameworks < ActiveRecord::Migration[5.2]
  def change
    create_table :coding_frameworks do |t|
      t.string :name, null: false
      t.integer :structure, null: false
      t.string :uri_base

      t.timestamps
    end
  end
end
