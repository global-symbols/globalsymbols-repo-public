class AddLicenceToSymbolset < ActiveRecord::Migration[5.2]
  def change
    add_reference :symbolsets, :licence, foreign_key: true, null: false, after: :id
  end
end
