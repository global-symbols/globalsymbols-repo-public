class AddFeedbackFieldsToComments < ActiveRecord::Migration[5.2]
  def change
    rename_column :comments, :likert1, :representation_rating
    
    add_column :comments, :contrast_rating, :integer, after: :representation_rating
    add_column :comments, :cultural_rating, :integer, after: :contrast_rating
  end
end
