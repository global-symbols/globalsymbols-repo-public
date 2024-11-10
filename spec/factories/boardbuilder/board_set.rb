FactoryBot.define do
  factory :board_set, class: Boardbuilder::BoardSet do
    sequence(:name) {|n| "Board Set #{n}" }

    transient do
      owner { FactoryBot.create :user }
      additional_users_count { 0 }
      boards_count { 0 }
    end

    # Add board_set_users after build, for validation
    after :build do |board_set, e|
      board_set.board_set_users << FactoryBot.build(:board_set_user, user: e.owner, board_set: board_set, role: :owner)
      board_set.board_set_users << FactoryBot.build_list(:board_set_user, e.additional_users_count, board_set: board_set, role: :editor)
    end

    # Add boards after create
    after :create do |board_set, e|
      board_set.boards          << FactoryBot.create_list(:board, e.boards_count, board_set: board_set)
    end
  end
end