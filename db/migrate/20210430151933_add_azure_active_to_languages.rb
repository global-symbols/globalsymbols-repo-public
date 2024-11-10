class AddAzureActiveToLanguages < ActiveRecord::Migration[6.1]
  def change
    add_column :languages, :azure_translate_supported, :boolean, after: :active
  end
end
