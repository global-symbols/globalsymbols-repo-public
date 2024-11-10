class ImagesController < ApplicationController

  skip_before_action :authenticate_user!, only: [:show]
  load_resource :image

  # When an Image.imagefile is replaced, Carrierwave changes the hash in the image file URL, and so the old URL stops working.
  # This controller handles 404 errors for Carrierwave uploads and redirects requests to new image files.
  def show
    redirect_to symbolset_symbol_path(@image.picto.symbolset, @image.picto, format: request.format.symbol)
  end
end
