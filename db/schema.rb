# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_08_26_120946) do

  create_table "active_storage_attachments", charset: "utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "boardbuilder_board_set_users", charset: "utf8", force: :cascade do |t|
    t.bigint "boardbuilder_board_set_id", null: false
    t.bigint "user_id", null: false
    t.integer "role", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["boardbuilder_board_set_id"], name: "index_boardbuilder_board_set_users_on_boardbuilder_board_set_id"
    t.index ["user_id"], name: "index_boardbuilder_board_set_users_on_user_id"
  end

  create_table "boardbuilder_board_sets", charset: "utf8", force: :cascade do |t|
    t.string "name"
    t.boolean "public"
    t.integer "featured_level"
    t.datetime "opened_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "boardbuilder_boards", charset: "utf8", force: :cascade do |t|
    t.bigint "boardbuilder_board_set_id", null: false
    t.string "name", null: false
    t.string "description"
    t.integer "index"
    t.integer "columns", null: false
    t.integer "rows", null: false
    t.integer "captions_position", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "header_boardbuilder_media_id"
    t.index ["boardbuilder_board_set_id"], name: "index_boardbuilder_boards_on_boardbuilder_board_set_id"
    t.index ["header_boardbuilder_media_id"], name: "index_boardbuilder_boards_on_header_boardbuilder_media_id"
  end

  create_table "boardbuilder_cells", charset: "utf8", force: :cascade do |t|
    t.bigint "boardbuilder_board_id", null: false
    t.bigint "linked_to_boardbuilder_board_id"
    t.bigint "picto_id"
    t.bigint "boardbuilder_media_id"
    t.string "caption"
    t.integer "index"
    t.string "background_colour"
    t.string "border_colour"
    t.string "text_colour"
    t.string "hair_colour"
    t.string "skin_colour"
    t.string "image_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["boardbuilder_board_id"], name: "index_boardbuilder_cells_on_boardbuilder_board_id"
    t.index ["boardbuilder_media_id"], name: "index_boardbuilder_cells_on_boardbuilder_media_id"
    t.index ["linked_to_boardbuilder_board_id"], name: "index_boardbuilder_cells_on_linked_to_boardbuilder_board_id"
    t.index ["picto_id"], name: "index_boardbuilder_cells_on_picto_id"
  end

  create_table "boardbuilder_media", charset: "utf8", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "file"
    t.string "format", null: false
    t.integer "filesize", null: false
    t.string "caption"
    t.integer "height"
    t.integer "width"
    t.string "canvas"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_boardbuilder_media_on_user_id"
  end

  create_table "categories", charset: "utf8", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "concept_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["concept_id"], name: "index_categories_on_concept_id"
  end

  create_table "coding_frameworks", charset: "utf8", force: :cascade do |t|
    t.string "name", null: false
    t.integer "structure", null: false
    t.string "api_uri_base"
    t.string "www_uri_base"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "comments", charset: "utf8", force: :cascade do |t|
    t.bigint "picto_id", null: false
    t.bigint "survey_response_id"
    t.bigint "user_id"
    t.integer "rating", null: false
    t.string "comment"
    t.integer "representation_rating"
    t.integer "contrast_rating"
    t.integer "cultural_rating"
    t.boolean "read"
    t.boolean "resolved"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["picto_id"], name: "index_comments_on_picto_id"
    t.index ["survey_response_id"], name: "index_comments_on_survey_response_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "concepts", charset: "utf8", force: :cascade do |t|
    t.bigint "coding_framework_id", null: false
    t.bigint "language_id"
    t.string "subject", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coding_framework_id"], name: "index_concepts_on_coding_framework_id"
    t.index ["language_id"], name: "index_concepts_on_language_id"
  end

  create_table "images", charset: "utf8", force: :cascade do |t|
    t.bigint "picto_id", null: false
    t.boolean "adaptable", default: false, null: false
    t.string "imagefile"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["picto_id"], name: "index_images_on_picto_id"
  end

  create_table "import_jobs", charset: "utf8", force: :cascade do |t|
    t.bigint "symbolset_id"
    t.integer "status"
    t.string "message"
    t.boolean "csv_valid"
    t.boolean "symbols_valid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["symbolset_id"], name: "index_import_jobs_on_symbolset_id"
  end

  create_table "labels", charset: "utf8", force: :cascade do |t|
    t.bigint "language_id", null: false
    t.bigint "picto_id", null: false
    t.bigint "source_id"
    t.string "text", null: false
    t.string "text_diacritised"
    t.text "description"
    t.datetime "pulled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["language_id", "text"], name: "index_labels_on_language_id_and_text"
    t.index ["language_id"], name: "index_labels_on_language_id"
    t.index ["picto_id"], name: "index_labels_on_picto_id"
    t.index ["source_id"], name: "index_labels_on_source_id"
    t.index ["text"], name: "index_labels_on_text"
    t.index ["text_diacritised"], name: "index_labels_on_text_diacritised"
  end

  create_table "languages", charset: "utf8", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.boolean "azure_translate_supported"
    t.bigint "language_id"
    t.string "name", limit: 150, null: false
    t.string "scope", limit: 1, null: false
    t.string "category", limit: 1, null: false
    t.string "iso639_3", limit: 3, null: false
    t.string "iso639_2b", limit: 3
    t.string "iso639_2t", limit: 3
    t.string "iso639_1", limit: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "category"], name: "index_languages_on_active_and_category"
    t.index ["iso639_1"], name: "index_languages_on_iso639_1"
    t.index ["iso639_3"], name: "index_languages_on_iso639_3", unique: true
    t.index ["language_id"], name: "index_languages_on_language_id"
    t.index ["name"], name: "index_languages_on_name"
  end

  create_table "licences", charset: "utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "url"
    t.string "version"
    t.string "properties"
    t.string "logo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "oauth_access_grants", charset: "utf8", force: :cascade do |t|
    t.bigint "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.string "code_challenge"
    t.string "code_challenge_method"
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", charset: "utf8", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", charset: "utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "oauth_openid_requests", charset: "utf8", force: :cascade do |t|
    t.bigint "access_grant_id", null: false
    t.string "nonce", null: false
    t.index ["access_grant_id"], name: "index_oauth_openid_requests_on_access_grant_id"
  end

  create_table "picto_concepts", charset: "utf8", force: :cascade do |t|
    t.bigint "concept_id"
    t.bigint "picto_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["concept_id"], name: "index_picto_concepts_on_concept_id"
    t.index ["picto_id"], name: "index_picto_concepts_on_picto_id"
  end

  create_table "pictos", charset: "utf8", force: :cascade do |t|
    t.bigint "category_id"
    t.bigint "source_id"
    t.bigint "symbolset_id", null: false
    t.integer "part_of_speech"
    t.string "publisher_ref"
    t.boolean "archived", default: false, null: false
    t.integer "visibility", default: 0, null: false
    t.datetime "pulled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["archived"], name: "index_pictos_on_archived"
    t.index ["category_id"], name: "index_pictos_on_category_id"
    t.index ["source_id"], name: "index_pictos_on_source_id"
    t.index ["symbolset_id", "archived"], name: "index_pictos_on_symbolset_id_and_archived"
    t.index ["symbolset_id", "publisher_ref"], name: "index_pictos_on_symbolset_id_and_publisher_ref"
    t.index ["symbolset_id"], name: "index_pictos_on_symbolset_id"
    t.index ["visibility"], name: "index_pictos_on_visibility"
  end

  create_table "sources", charset: "utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "authoritative", null: false
    t.boolean "suggestion", default: false, null: false
    t.text "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "survey_pictos", charset: "utf8", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.bigint "picto_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["picto_id"], name: "index_survey_pictos_on_picto_id"
    t.index ["survey_id"], name: "index_survey_pictos_on_survey_id"
  end

  create_table "survey_responses", charset: "utf8", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.bigint "user_id"
    t.string "name"
    t.string "organisation"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["survey_id"], name: "index_survey_responses_on_survey_id"
    t.index ["user_id"], name: "index_survey_responses_on_user_id"
  end

  create_table "surveys", charset: "utf8", force: :cascade do |t|
    t.bigint "symbolset_id", null: false
    t.bigint "previous_survey_id"
    t.bigint "language_id"
    t.string "name", null: false
    t.text "introduction"
    t.integer "status", null: false
    t.datetime "close_at"
    t.boolean "show_symbol_descriptions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["language_id"], name: "index_surveys_on_language_id"
    t.index ["previous_survey_id"], name: "index_surveys_on_previous_survey_id"
    t.index ["symbolset_id"], name: "index_surveys_on_symbolset_id"
  end

  create_table "symbolset_users", charset: "utf8", force: :cascade do |t|
    t.bigint "symbolset_id", null: false
    t.bigint "user_id", null: false
    t.integer "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["symbolset_id"], name: "index_symbolset_users_on_symbolset_id"
    t.index ["user_id"], name: "index_symbolset_users_on_user_id"
  end

  create_table "symbolsets", charset: "utf8", force: :cascade do |t|
    t.bigint "licence_id", null: false
    t.string "name", null: false
    t.string "description"
    t.string "publisher", null: false
    t.string "publisher_url"
    t.string "logo"
    t.integer "status", null: false
    t.string "slug", null: false
    t.boolean "auto_update"
    t.integer "featured_level"
    t.datetime "pulled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["licence_id"], name: "index_symbolsets_on_licence_id"
    t.index ["status"], name: "index_symbolsets_on_status"
  end

  create_table "users", charset: "utf8", force: :cascade do |t|
    t.bigint "language_id"
    t.string "email", default: "", null: false
    t.integer "role", null: false
    t.string "prename"
    t.string "surname"
    t.string "company"
    t.string "location"
    t.string "default_hair_colour"
    t.string "default_skin_colour"
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["language_id"], name: "index_users_on_language_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "boardbuilder_board_set_users", "boardbuilder_board_sets"
  add_foreign_key "boardbuilder_board_set_users", "users"
  add_foreign_key "boardbuilder_boards", "boardbuilder_board_sets"
  add_foreign_key "boardbuilder_boards", "boardbuilder_media", column: "header_boardbuilder_media_id"
  add_foreign_key "boardbuilder_cells", "boardbuilder_boards"
  add_foreign_key "boardbuilder_cells", "boardbuilder_boards", column: "linked_to_boardbuilder_board_id"
  add_foreign_key "boardbuilder_cells", "boardbuilder_media", column: "boardbuilder_media_id"
  add_foreign_key "boardbuilder_cells", "pictos"
  add_foreign_key "boardbuilder_media", "users"
  add_foreign_key "categories", "concepts"
  add_foreign_key "comments", "pictos"
  add_foreign_key "comments", "survey_responses"
  add_foreign_key "comments", "users"
  add_foreign_key "concepts", "coding_frameworks"
  add_foreign_key "concepts", "languages"
  add_foreign_key "images", "pictos"
  add_foreign_key "import_jobs", "symbolsets"
  add_foreign_key "labels", "languages"
  add_foreign_key "labels", "pictos"
  add_foreign_key "labels", "sources"
  add_foreign_key "languages", "languages"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_grants", "users", column: "resource_owner_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "users", column: "resource_owner_id"
  add_foreign_key "oauth_openid_requests", "oauth_access_grants", column: "access_grant_id", on_delete: :cascade
  add_foreign_key "picto_concepts", "concepts"
  add_foreign_key "picto_concepts", "pictos"
  add_foreign_key "pictos", "categories"
  add_foreign_key "pictos", "sources"
  add_foreign_key "pictos", "symbolsets"
  add_foreign_key "survey_pictos", "pictos"
  add_foreign_key "survey_pictos", "surveys"
  add_foreign_key "survey_responses", "surveys"
  add_foreign_key "survey_responses", "users"
  add_foreign_key "surveys", "languages"
  add_foreign_key "surveys", "surveys", column: "previous_survey_id"
  add_foreign_key "surveys", "symbolsets"
  add_foreign_key "symbolset_users", "symbolsets"
  add_foreign_key "symbolset_users", "users"
  add_foreign_key "symbolsets", "licences"
  add_foreign_key "users", "languages"
end
