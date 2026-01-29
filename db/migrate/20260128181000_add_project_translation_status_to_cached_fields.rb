class AddProjectTranslationStatusToCachedFields < ActiveRecord::Migration[6.1]
  def up
    collection = DirectusCachedCollection.find_by(name: 'projects')
    return if collection.blank?

    updated = collection.parameter_sets.map do |ps|
      next ps unless ps.is_a?(Hash) && ps['fields'].is_a?(String)

      fields = ps['fields']
      next ps if fields.include?('translations.status')

      # Keep ordering: add status alongside other translation fields.
      ps.merge('fields' => fields.sub('translations.project_details,', 'translations.project_details,translations.status,'))
    end

    collection.update!(parameter_sets: updated)
  end

  def down
    collection = DirectusCachedCollection.find_by(name: 'projects')
    return if collection.blank?

    updated = collection.parameter_sets.map do |ps|
      next ps unless ps.is_a?(Hash) && ps['fields'].is_a?(String)

      ps.merge('fields' => ps['fields'].gsub('translations.status,', ''))
    end

    collection.update!(parameter_sets: updated)
  end
end

