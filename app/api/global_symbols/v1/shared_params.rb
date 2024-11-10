module GlobalSymbols
  module V1::SharedParams
    extend Grape::API::Helpers

    params :expand do
      # Accepts types Array[String] and String.
      # String is the initial input type, and ensures that Swagger offers the correct input type.
      # Array[String] is the result after coercion.
      optional :expand, types: [Array[String], String], desc: 'Space-separated of fields to expand.', default: [], coerce_with: ->(val) { val.split(/\s+/) }
    end
  end
end