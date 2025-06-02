class AddStatusToImages < ActiveRecord::Migration[6.1]
  def change
    add_column :images, :status, :string, default: 'pending'
  end
end
