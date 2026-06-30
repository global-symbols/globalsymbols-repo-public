module GlobalSymbols
  module V1::SharedHelpers
    extend Grape::API::Helpers

    # Public Global Symbols endpoints allow guest access; grape-cancan builds Ability from current_user.
    def current_user
      nil
    end
  end
end