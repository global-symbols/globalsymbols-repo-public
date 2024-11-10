module GlobalSymbols
  class V1::Entities::Error < Grape::Entity
    expose :code
    expose :error
  end
end