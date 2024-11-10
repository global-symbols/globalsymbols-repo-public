class API < Grape::API
  mount GlobalSymbols::V1::Base, at: '/v1'
  mount BoardBuilder::V1::Base#, at: '/boardbuilder/v1'
end
