require 'base64'

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

  # Computes a stable, pseudonymized hash for the authenticated user id.
  # Uses HMAC-SHA256 with an application secret so it cannot be reversed or forged by clients.
  def current_user_id_hash
    # Prefer a dedicated secret if configured
    # Hardcoded fallback (for dev only) to avoid nil hashes when secrets are not set.
    dev_fallback_secret = ''
    secret = ENV['AI_ANALYTICS_HASH_SECRET'].presence || dev_fallback_secret
    return nil if secret.blank?

    # Determine an identifier to hash using server-side sources only:
    # 1) Doorkeeper token lookup for resource_owner_id
    # 2) Fallback to current_user.id if present
    ro_id = resource_owner_id_from_tokens
    user_id_str = ro_id.present? ? ro_id.to_s : (current_user&.id&.to_s)

    return nil if user_id_str.blank?

    digest_bytes = OpenSSL::HMAC.digest('SHA256', secret, user_id_str)
    Base64.urlsafe_encode64(digest_bytes, padding: false)
  end

  # Extract raw bearer token from Authorization header
  def bearer_token
    auth = headers['Authorization'] || headers['authorization']
    return nil if auth.blank?
    scheme, token = auth.to_s.split(' ', 2)
    return nil unless scheme&.casecmp('Bearer')&.zero?
    token.presence
  end

  # Try to resolve resource_owner_id using Doorkeeper token objects or DB
  def resource_owner_id_from_tokens
    # Prefer doorkeeper_token helper if available
    if respond_to?(:doorkeeper_token) && doorkeeper_token
      ro_id = doorkeeper_token.resource_owner_id
      return ro_id if ro_id.present?
      # If token is opaque and persisted, attempt DB lookup by token string
      begin
        token_str = doorkeeper_token.token if doorkeeper_token.respond_to?(:token)
        token_str ||= bearer_token
        if token_str.present? && defined?(Doorkeeper::AccessToken)
          db_token = Doorkeeper::AccessToken.by_token(token_str)
          return db_token.resource_owner_id if db_token&.resource_owner_id.present?
        end
      rescue StandardError
        # ignore
      end
    else
      # As a last resort, try DB lookup with raw bearer token
      token_str = bearer_token
      if token_str.present? && defined?(Doorkeeper::AccessToken)
        begin
          db_token = Doorkeeper::AccessToken.by_token(token_str)
          return db_token.resource_owner_id if db_token&.resource_owner_id.present?
        rescue StandardError
          # ignore
        end
      end
    end
    nil
  end

  # saves a board_set efficiently
  # instead of one SQL command per cell for board_set.save,
  # this saves all cells in on single bulk SQL insert query
  def save_board_set(board_set_params)
    board_set_params = ActiveSupport::HashWithIndifferentAccess.new(board_set_params)
    boards = board_set_params[:boards]
    board_set_params[:boards] = []
    board_set = Boardbuilder::BoardSet.new(board_set_params)
    board_set.users << resource_owner
    if board_set.author.blank?
      board_set.author = "#{resource_owner.prename} #{resource_owner.surname}"
    end
    if board_set.lang.blank?
      board_set.lang = resource_owner.language.iso639_1
    end
    board_set.lang = board_set.lang[0, 2].downcase
    obf_id_to_gs_id = {}
    cells_of_board = [] # cells_of_board[index] contains cells of board_set.boards[index]
    all_cells = []

    Boardbuilder::BoardSet.transaction do
      board_set.save! # Save the board_set to obtain its ID
      boards.each_with_index do |board, index|
        board[:boardbuilder_board_set_id] = board_set.id
        cells_of_board[index] = board[:cells]
        board[:cells] = []
        obf_id = board[:obf_id]
        board.delete(:obf_id)
        db_board = Boardbuilder::BoardNoAutocells.new(board)
        db_board.save!
        board[:id] = db_board.id
        obf_id_to_gs_id[obf_id] = db_board.id
      end
      boards.each_with_index do |board, index|
        cells_of_board[index].each_with_index do |cell, index|
          if !cell.blank? and !cell[:linked_to_obf_id].blank?
            cell[:linked_to_boardbuilder_board_id] = obf_id_to_gs_id[cell[:linked_to_obf_id]]
          end
          cell.delete(:linked_to_obf_id)
          cell[:boardbuilder_board_id] = board[:id]
          cell[:index] = index + 1
          cell[:created_at] = Time.current
          cell[:updated_at] = Time.current
          all_cells << Boardbuilder::Cell.new(cell).attributes
        end
      end
      Boardbuilder::Cell.insert_all(all_cells)
    end
    board_set
  end

  # Saves a collection of images based on the provided file map. Ensures that no duplicates are saved.
  #
  # @param file_map [Hash] A hash where the keys are identifiers (such as file names or IDs)
  #   and the values are the files themselves (base64 encoded).
  # @param return_media [Boolean] (default: false) Whether to return the created `Media` instances.
  #   - If `true`, returns a hash of filename -> `Media` objects.
  #   - If `false`, returns a hash of filename -> url (String).
  def save_images(file_map, return_media: false, resize_image_width: nil, resize_image_height: nil)
    filename_to_content = file_map.select do |filename, _|
      Rails.application.config.allowed_image_extensions.any? { |ext| filename.is_a?(Numeric) || filename.downcase.end_with?(".#{ext}") }
    end

    user = current_user
    filename_to_media = filename_to_content.map do |filename, _|
      media = Boardbuilder::Media.new(user: user, file: filename_to_content[filename], resize_width: resize_image_width, resize_height: resize_image_height)
      [filename, media]
    end.to_h

    new_files_hashes = filename_to_media.values.map(&:file_hash)
    media_of_user = Boardbuilder::Media.where(user_id: current_user.id).where.not(file_hash: nil)
    existing_hashes = media_of_user.pluck(:file_hash)
    non_existing_hashes = new_files_hashes - existing_hashes
    missing_files = filename_to_media.select { |_, media| non_existing_hashes.include?(media.file_hash) }

    missing_files.each do |_, media|
      if !media.save
        Rails.logger.warn "Save image failed: #{media.errors.full_messages.join(', ')}"
      end
    end

    filename_to_media = filename_to_media.select { |_, media| !media.file_hash.blank? }
    filename_to_media = filename_to_media.map do |filename, media|
      if media&.id.blank? # if id is blank, it's not saved to database, don't check for file, since a temp file is created for hash calculation
        media = media_of_user.find_by(file_hash: media.file_hash)
        Rails.logger.debug "[EXISTED] media was existing: #{filename}"
      else
        Rails.logger.debug "[UPLOADED] media was new: #{filename}"
      end
      [filename, media]
    end.to_h

    filename_to_media = filename_to_media.select { |_, media| !media&.file&.url&.blank? }
    return_media ? filename_to_media : filename_to_media.map { |filename, media| [filename, media.file.url] }.to_h
  end

  def save_image(base64_content, resize_image_width: nil, resize_image_height: nil)
    save_images({1 => base64_content}, return_media: true, resize_image_width: resize_image_width, resize_image_height: resize_image_height)[1]
  end
end