class CreateLicences < ActiveRecord::Migration[5.2]
  def change
    create_table :licences do |t|
      t.string :name, null: false
      t.string :url
      t.string :version
      t.string :properties
      t.string :logo

      t.timestamps
    end
  end
end
