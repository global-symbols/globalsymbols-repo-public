class Boardbuilder::BoardNoAutocells < Boardbuilder::Board
  after_create :populate_cells
  after_update :populate_cells

  private
  def populate_cells
  end
end