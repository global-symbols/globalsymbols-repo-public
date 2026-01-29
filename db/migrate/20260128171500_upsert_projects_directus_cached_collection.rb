class UpsertProjectsDirectusCachedCollection < ActiveRecord::Migration[6.1]
  def up
    collection = DirectusCachedCollection.find_or_initialize_by(name: 'projects')
    collection.parameter_sets = [
      {
        'fields' => 'id,status,sort,slug,date_created,date_updated,thumbnail,categories.project_categories_id.name,categories.project_categories_id.id,translations.title,translations.short_description,translations.project_details,translations.gs_languages_code',
        'filter' => { 'status' => { '_eq' => 'published' } },
        'limit' => 1000
      }
    ]
    collection.priority = 9
    collection.description = 'Projects'
    collection.active = true
    collection.save!
  end

  def down
    DirectusCachedCollection.where(name: 'projects').delete_all
  end
end

