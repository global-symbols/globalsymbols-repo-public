class User < ApplicationRecord
  
  belongs_to :language, inverse_of: :users

  has_many :boardbuilder_board_set_users, class_name: 'Boardbuilder::BoardSetUser', inverse_of: :user
  has_many :boardbuilder_board_sets, class_name: 'Boardbuilder::BoardSet', through: :boardbuilder_board_set_users, source: :board_set, inverse_of: :users
  has_many :boardbuilder_library_images, class_name: 'Boardbuilder::Media', inverse_of: :user
  has_many :comments, inverse_of: :user
  has_many :survey_responses, inverse_of: :user
  has_many :symbolset_users, inverse_of: :user
  has_many :symbolsets, through: :symbolset_users, inverse_of: :users

  has_many :access_grants,
           class_name: 'Doorkeeper::AccessGrant',
           foreign_key: :resource_owner_id,
           dependent: :delete_all # or :destroy if you need callbacks

  has_many :access_tokens,
           class_name: 'Doorkeeper::AccessToken',
           foreign_key: :resource_owner_id,
           dependent: :delete_all # or :destroy if you need callbacks

  enum role: [:user, :admin]
  
  validates_presence_of :prename, :surname, :language

  validates :default_hair_colour, format: { with: /\A#?(?:[A-F0-9]{3}){1,2}\z/i, message: "must be a hexadecimal colour code" }, allow_blank: true
  validates :default_skin_colour, format: { with: /\A#?(?:[A-F0-9]{3}){1,2}\z/i, message: "must be a hexadecimal colour code" }, allow_blank: true

  after_initialize :set_default_role, :if => :new_record?
  
  # TODO: When ready to create views, use rails generate devise:views
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  private
    def set_default_role
      self.role ||= :user
    end
end
