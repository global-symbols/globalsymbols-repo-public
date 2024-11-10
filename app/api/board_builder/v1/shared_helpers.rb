module BoardBuilder::V1::SharedHelpers
  extend Grape::API::Helpers

  params :expand do
    optional :expand, type: Array[String], desc: 'Space-separated of fields to expand.', default: [], coerce_with: ->(val) { val.split(/\s+/) }
  end

  # def current_user
  #   @current_user ||= User.authorize!(env)
  # end

  def current_user
    resource_owner
  end

  def authenticate!
    error!({ error: "Unauthorized",
             code: 401,
             with: V1::Entities::Error},
           401) unless current_user
  end
end