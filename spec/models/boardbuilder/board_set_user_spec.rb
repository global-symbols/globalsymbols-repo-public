require 'rails_helper'

RSpec.describe Boardbuilder::BoardSetUser, type: :model do
  context 'with valid parameters' do
    it 'validates and creates an owner board_set_user' do
      board_set_user = FactoryBot.create(:board_set_user)
      expect(board_set_user.role).to eq('owner')
    end

    it 'returns the correct records when traversing to User or BoardSet' do
      board_set = FactoryBot.create(:board_set)
      user = FactoryBot.create(:user)
      board_set_user = FactoryBot.create(:board_set_user, user:user, board_set:board_set)
      expect(board_set_user.board_set).to be(board_set)
      expect(board_set_user.user).to be(user)
    end
  end

  context 'invalid parameters' do
    it 'fails validation without a board_set' do
      expect{FactoryBot.create(:board_set_user, board_set: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
    it 'fails validation without a user' do
      expect{FactoryBot.create(:board_set_user, user: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
    it 'fails validation without a role' do
      expect{FactoryBot.create(:board_set_user, role: nil)}.to raise_error ActiveRecord::RecordInvalid
    end

    it 'fails validation when trying to create a duplicate BoardSet/User combination' do
      bsu = FactoryBot.create(:board_set_user)
      expect{FactoryBot.create(:board_set_user, board_set: bsu.board_set, user: bsu.user)}.to raise_error ActiveRecord::RecordInvalid
    end
  end

  context 'with a User, BoardSet and edutor role specified' do
    it 'validates and creates an editor board_set_user' do
      board_set_user = FactoryBot.create(:board_set_user, :editor)

      expect(board_set_user.role).to eq('editor')
    end
  end
end
