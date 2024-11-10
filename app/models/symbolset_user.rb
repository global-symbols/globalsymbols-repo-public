class SymbolsetUser < ApplicationRecord
  belongs_to :symbolset, inverse_of: :symbolset_users, validate: true
  belongs_to :user, inverse_of: :symbolset_users
  
  enum role: [:editor, :admin]

  validates_presence_of :symbolset, :user, :role
  validates_uniqueness_of :user, scope: :symbolset
  
  after_initialize :set_default_role, :if => :new_record?
  
  private
    def set_default_role
      self.role ||= :editor
    end
end
