class Symbolset < ApplicationRecord
  # Max symbols shown / batch-translated on the manager translate page.
  TRANSLATION_BATCH_LIMIT = 35

  belongs_to :licence, inverse_of: :symbolsets
  
  has_many :pictos, inverse_of: :symbolset, dependent: :destroy
  has_many :surveys, inverse_of: :symbolset, dependent: :destroy
  has_many :symbolset_users, inverse_of: :symbolset, dependent: :destroy

  has_many :labels, through: :pictos
  has_many :users, through: :symbolset_users, inverse_of: :symbolsets

  extend FriendlyId
  friendly_id :name, use: [:slugged]

  mount_uploader :logo, SymbolsetLogoUploader
  has_one_attached :zip_bundle
  
  validates_presence_of :name, :publisher, :slug, :status, :licence_id
  validates_uniqueness_of :name, :slug
  validates_format_of :slug, with: /\A[\w-]+\Z/
  validate :status_must_be_draft, on: :create
  validate :slug_is_not_a_route

  enum :status, { published: 0, draft: 1, ingesting: 2 }
  
  after_initialize :set_defaults, if: :new_record?

  # Pictos eligible for the translate UI: authoritative source label present,
  # and no authoritative destination label yet (suggestions still appear for review).
  # Shared with TranslationController#suggest_all re-render so page and batch stay aligned.
  def pictos_for_translation(source_language:, destination_language:, limit: TRANSLATION_BATCH_LIMIT)
    return pictos.none if source_language.blank? || destination_language.blank?

    non_archived = pictos.where(archived: false)

    source_picto_ids = Label.unscoped
                            .joins(:source)
                            .where(
                              language: source_language,
                              picto_id: non_archived.select(:id),
                              sources: { authoritative: true }
                            )
                            .select(:picto_id)

    dest_auth_picto_ids = Label.unscoped
                               .joins(:source)
                               .where(
                                 language: destination_language,
                                 picto_id: non_archived.select(:id),
                                 sources: { authoritative: true }
                               )
                               .select(:picto_id)

    non_archived
      .where(id: source_picto_ids)
      .where.not(id: dest_auth_picto_ids)
      .order(:id)
      .limit(limit)
  end

  # Authoritative source-language labels whose pictos have no destination label yet
  # (suggestion or published). Used by batch Azure translate.
  def source_labels_for_batch_translation(source_language:, destination_language:, limit: TRANSLATION_BATCH_LIMIT)
    return Label.none if source_language.blank? || destination_language.blank?

    non_archived_ids = pictos.where(archived: false).select(:id)

    existing_dest_picto_ids = Label.unscoped
                                   .where(language: destination_language, picto_id: non_archived_ids)
                                   .select(:picto_id)

    Label.unscoped
         .joins(:source)
         .where(
           language: source_language,
           picto_id: non_archived_ids,
           sources: { authoritative: true }
         )
         .where.not(picto_id: existing_dest_picto_ids)
         .order(:picto_id, :id)
         .limit(limit)
  end

  private

  def set_defaults
    self.status ||= :draft
  end

  def slug_is_not_a_route
    # TODO: Add test coverage when we have a route
    path = ActionController::Routing::Routes.recognize_path("/#{name}", :method => :get) rescue nil
    errors.add(:name, "conflicts with existing path (/#{name})") if path && !path[:username]
  end

  def status_must_be_draft
    errors.add(:status, "must be draft for new Symbolsets") if status != 'draft'
  end
end
