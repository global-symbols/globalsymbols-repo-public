class AddIndexToSymbolsetsStatus < ActiveRecord::Migration[6.1]
  def change
    add_index :symbolsets, :status
  end
end
