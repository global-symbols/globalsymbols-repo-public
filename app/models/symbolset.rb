class Symbolset < ApplicationRecord
  
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

  enum status: { published: 0, draft: 1, ingesting: 2 }
  
  after_initialize :set_defaults, if: :new_record?
  
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
