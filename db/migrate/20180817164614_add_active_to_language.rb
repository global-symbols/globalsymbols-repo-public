class AddActiveToLanguage < ActiveRecord::Migration[5.2]
  def change
    add_column :languages, :active, :boolean, after: :id, null: false, default: 0
  end
end
