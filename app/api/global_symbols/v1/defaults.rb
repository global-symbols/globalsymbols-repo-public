module GlobalSymbols
  module V1::Defaults
    extend ActiveSupport::Concern

    included do
      helpers V1::SharedParams
      helpers V1::SharedHelpers
    end
  end
end