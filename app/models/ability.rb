class Ability
  include CanCan::Ability

  def initialize(user)
  
    # Guests can see published Symbolsets
    can [:index, :show, :home, :search, :download], Symbolset, status: :published

    # Guests can see public Pictos from published Symbolsets
    can [:index, :show, :download], Picto, symbolset: {status: :published}, visibility: :everybody, archived: false

    # Guests can see Labels of Published Symbols in published Symbolsets
    can [:index, :show, :read], Label, picto: {visibility: :everybody, archived: false, symbolset: {status: Symbolset.statuses[:published]}}
    
    # Guests can see all Concepts
    can :show, Concept
    
    # Guests can participate in Surveys
    can [:show, :print, :create_response, :thank_you], Survey
    
    # Permissions for logged-in Users
    if user.present?
      
      # Users can create Symbolsets
      can :create, Symbolset
      
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

      # can :manage, SymbolsetUser do |ssu|
      #   ssu.symbolset.users.exists?(user.id)
      # end

      # BOARDS OWNED BY A USER
      # Users can create Boardbuilder::BoardSets
      can :create, Boardbuilder::BoardSet

      # Users can manage Boardbuilder::BoardSets they are assigned to
      can :manage, Boardbuilder::BoardSet, board_set_users: { user_id: user.id }

      # Users can manage Collaborators of Boardbuilder::BoardSets they are assigned to
      # can :manage, Boardbuilder::BoardSetUser, boardbuilder_board_set_id: user.boardbuilder_board_sets.ids
      can :manage, Boardbuilder::BoardSetUser, board_set: { board_set_users: { user_id: user.id } }

      # Users can manage Boards of Boardbuilder::BoardSets they are assigned to
      can :manage, Boardbuilder::Board, board_set: { board_set_users: { user_id: user.id } }

      # Users can view and edit Cells of Boardbuilder::Boards they are assigned to
      can :manage, Boardbuilder::Cell, board: { board_set: { board_set_users: { user_id: user.id } } }
      # END BOARDS OWNED BY A USER

      # PUBLIC BOARDS

      # Users can read public Boardbuilder::BoardSets
      can :read, Boardbuilder::BoardSet, public: true

      # Users can read Boards in public Boardbuilder::BoardSets
      can :read, Boardbuilder::Board, board_set: { public: true }

      # END PUBLIC BOARDS

      # Users can manage Media they own
      can :manage, Boardbuilder::Media, user_id: user.id

      # additional permissions for administrators
      if user.admin?
        # Instead of allowing :all, we specify rights on individual models.
        # This ensures Admins can't see private content, such as user-generated BoardBuilder records.
        can :manage, SymbolsetUser
        can :manage, Symbolset
        can :manage, Picto
        can :manage, Image
        can :manage, Label
        can :manage, PictoConcept
        can :manage, Survey
        can :manage, SurveyPicto
        can :manage, SurveyResponse
      end
    end
    
    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities
  end
end
