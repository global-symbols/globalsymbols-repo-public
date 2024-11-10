require 'rails_helper'

RSpec.describe Boardbuilder::BoardSet, type: :model do
  context 'with minimum parameters' do
    it 'creates a private BoardSet' do
      boardset = FactoryBot.create(:board_set)
      expect(boardset.public).to eq false
    end
  end

  describe 'validations' do
    it 'is invalid without a name' do
      expect{FactoryBot.create(:board_set, name: nil)}.to raise_exception ActiveRecord::RecordInvalid
    end

    it 'is invalid with no BoardSetUsers' do
      expect{FactoryBot.create(:board_set, owner: nil)}.to raise_exception ActiveRecord::RecordInvalid
    end
  end
end
