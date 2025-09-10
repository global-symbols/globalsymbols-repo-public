# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    # Guests can see published Symbolsets
    can [:index, :show, :home, :search, :download], Symbolset, status: :published

    # Guests can see public Pictos from published Symbolsets
    can [:index, :show, :download], Picto, symbolset: { status: :published }, visibility: :everybody, archived: false

    # Guests can see Labels of Published Symbols in published Symbolsets
    can [:index, :show, :read], Label, picto: { visibility: :everybody, archived: false, symbolset: { status: Symbolset.statuses[:published] } }

    # Guests can see all Concepts
    can :show, Concept

    # Guests can participate in Surveys
    can [:show, :print, :create_response, :thank_you], Survey

    # Permissions for logged-in Users
    if user.present?
      # Allow AI generation for signed-in users
      can :manage, :ai
      # Users can create Symbolsets
      can :create, Symbolset

      # Users can create Pictos for Symbolsets they manage
      can :create, Picto, symbolset: { symbolset_users: { user_id: user.id } }

      # Users can manage Symbolsets they are assigned to
      can :manage, Symbolset, symbolset_users: { user_id: user.id }
      can :manage, Picto, symbolset: { symbolset_users: { user_id: user.id } }
      can :manage, PictoConcept, picto: { symbolset: { symbolset_users: { user_id: user.id } } }
      can :manage, Label, picto: { symbolset: { symbolset_users: { user_id: user.id } } }

      # Users can manage Collaborators of Symbolsets they are assigned to
      can :manage, SymbolsetUser, symbolset: { symbolset_users: { user_id: user.id } }

      # Users can manage Surveys on Symbolsets they are assigned to
      can :manage, Survey, symbolset: { symbolset_users: { user_id: user.id } }
      can :manage, SurveyResponse, survey: { symbolset: { symbolset_users: { user_id: user.id } } }

      # BOARDS OWNED BY A USER
      can :create, Boardbuilder::BoardSet
      can :manage, Boardbuilder::BoardSet, board_set_users: { user_id: user.id }
      can :manage, Boardbuilder::BoardSetUser, board_set: { board_set_users: { user_id: user.id } }
      can :manage, Boardbuilder::Board, board_set: { board_set_users: { user_id: user.id } }
      can :manage, Boardbuilder::Cell, board: { board_set: { board_set_users: { user_id: user.id } } }

      # PUBLIC BOARDS
      can :read, Boardbuilder::BoardSet, public: true
      can :read, Boardbuilder::Board, board_set: { public: true }

      # Users can manage Media they own
      can :manage, Boardbuilder::Media, user_id: user.id

      # Restrict bulk upload and metadata actions for non-admins
      unless user.admin?
        cannot :bulk_upload, Symbolset
        cannot :metadata, Symbolset
        cannot :update_labels, Symbolset
      end

      # Additional permissions for administrators
      if user.admin?
        can :manage, SymbolsetUser
        can :manage, Symbolset
        can :bulk_upload, Symbolset # Explicit for clarity
        can :metadata, Symbolset # Explicit for clarity
        can :update_labels, Symbolset # Explicit for clarity
        can :manage, Picto
        can :manage, Image
        can :manage, Label
        can :manage, PictoConcept
        can :manage, Survey
        can :manage, SurveyPicto
        can :manage, SurveyResponse
      end
    end
  end
end
