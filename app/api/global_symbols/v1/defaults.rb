module GlobalSymbols
  module V1::Defaults
    extend ActiveSupport::Concern

    included do
      helpers V1::SharedParams
    end
  end
end