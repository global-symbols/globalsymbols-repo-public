module GlobalSymbols
  class V1::Entities::User < Grape::Entity
    expose :id
    expose :prename
    expose :surname
    expose :default_hair_colour
    expose :default_skin_colour
  end
end