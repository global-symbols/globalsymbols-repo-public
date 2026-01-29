# frozen_string_literal: true

class ProjectsController < ApplicationController
  # Anyone can view this page
  skip_before_action :authenticate_user!

  # Breadcrumbs
  add_breadcrumb 'projects', :projects, only: [:index, :show]

  PROJECTS_PER_PAGE = 9
  PROJECTS_LIMIT = 1000
  PROJECT_FIELDS_INDEX = 'id,status,sort,slug,date_created,date_updated,thumbnail,categories.project_categories_id.name,categories.project_categories_id.id,translations.title,translations.short_description,translations.project_details,translations.status,translations.gs_languages_code'
  PROJECT_FIELDS_SHOW = 'id,status,sort,slug,date_created,date_updated,thumbnail,gallery.directus_files_id.id,gallery.directus_files_id.title,gallery.directus_files_id.filename_download,gallery.directus_files_id.type,categories.project_categories_id.name,categories.project_categories_id.id,translations.title,translations.short_description,translations.project_details,translations.status,translations.gs_languages_code'

  def index
    language_code = directus_language_code

    @current_page = (params[:page] || 1).to_i
    @selected_category = params[:category].presence
    @projects_per_page = PROJECTS_PER_PAGE

    begin
      all_projects = DirectusService.fetch_collection_with_translations(
        'projects',
        language_code,
        {
          'fields' => PROJECT_FIELDS_INDEX,
          'filter' => { 'status' => { '_eq' => 'published' } },
          'limit' => PROJECTS_LIMIT
        },
        nil,
        true,
        { skip_translation_filter: true }
      )

      projects = Array(all_projects)

      raw_categories = projects.flat_map do |project|
        categories_value = project.is_a?(Hash) ? project['categories'] : nil
        if categories_value.is_a?(Array) && categories_value.first.is_a?(Hash)
          categories_value.map { |junction| junction.dig('project_categories_id', 'name') }.compact
        else
          []
        end
      end

      @categories = raw_categories.reject { |c| c.nil? || c.to_s.empty? }.map(&:to_s).uniq.sort

      if @selected_category.present?
        projects = projects.select do |project|
          categories_value = project['categories']
          if categories_value.is_a?(Array) && categories_value.first.is_a?(Hash)
            categories_value.any? { |junction| junction.dig('project_categories_id', 'name') == @selected_category }
          else
            false
          end
        end
      end

      projects = projects.sort_by do |project|
        sort_val = project['sort']
        date_val = project['date_created'] || project['date_updated']
        parsed_date = date_val.present? ? (Date.parse(date_val) rescue Date.new(1900)) : Date.new(1900)
        [
          sort_val.nil? ? 1 : 0,
          sort_val.to_i,
          -parsed_date.jd
        ]
      end

      @total_projects = projects.length
      @total_pages = (@total_projects.to_f / @projects_per_page).ceil
      start_index = (@current_page - 1) * @projects_per_page
      end_index = start_index + @projects_per_page - 1
      @projects = projects[start_index..end_index] || []

      @has_previous_page = @current_page > 1
      @has_next_page = @current_page < @total_pages
      @previous_page = @current_page - 1
      @next_page = @current_page + 1
    rescue => e
      Rails.logger.error("Failed to fetch projects from Directus: #{e.message}")
      Rails.logger.error("Error class: #{e.class}, Backtrace: #{e.backtrace.join("\n")}")
      @projects = []
      @categories = []
      @total_pages = 0
      @directus_error = true
    end
  end

  def show
    language_code = directus_language_code

    begin
      # Cache-friendly pattern: fetch all projects (1 request per locale) then select by slug in Rails.
      projects = DirectusService.fetch_collection_with_translations(
        'projects',
        language_code,
        {
          'fields' => PROJECT_FIELDS_SHOW,
          'filter' => { 'status' => { '_eq' => 'published' } },
          'limit' => PROJECTS_LIMIT
        },
        nil,
        true,
        { skip_translation_filter: true }
      )

      @project = Array(projects).find { |p| p.is_a?(Hash) && p['slug'].to_s == params[:slug].to_s }

      raise ActiveRecord::RecordNotFound if @project.blank?

      translations = @project['translations'] || []
      requested_translation = translations.find { |t| t.is_a?(Hash) && t['gs_languages_code'] == language_code }
      fallback_translation = translations.find { |t| t.is_a?(Hash) && t['gs_languages_code'] == DIRECTUS_DEFAULT_LANGUAGE.call }
      english_translation = translations.find { |t| t.is_a?(Hash) && t['gs_languages_code'] == 'en-GB' }

      @translation_used = requested_translation || fallback_translation || english_translation
      raise ActiveRecord::RecordNotFound if @translation_used.nil? || @translation_used['title'].blank?

      @using_fallback = requested_translation.nil? && (fallback_translation.present? || english_translation.present?)

      add_breadcrumb @project['slug'] || 'project'
    rescue DirectusError => e
      Rails.logger.error("Failed to fetch project with slug #{params[:slug]} from Directus: #{e.message}")
      raise ActiveRecord::RecordNotFound
    end
  end
end

