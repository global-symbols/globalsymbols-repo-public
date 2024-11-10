module BoardBuilder::V1
  class Templates < Grape::API

    helpers SharedHelpers

    resource :templates do


      desc 'Returns a list of permitted paper sizes',
           is_array: true
      oauth2 'boardset:read'
      get 'page_sizes' do
        present PDF::Core::PageGeometry::SIZES.map {|size| {
          name: size[0],
          x: size[1][0],
          y: size[1][1],
        }}
      end

    end
  end
end
