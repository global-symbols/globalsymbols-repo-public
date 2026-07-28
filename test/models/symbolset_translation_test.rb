# frozen_string_literal: true

require 'test_helper'

class SymbolsetTranslationTest < ActiveSupport::TestCase
  setup do
    @symbolset = create(:symbolset, users_count: 0)
    @auth_source = create(:source, authoritative: true, slug: "auth-#{SecureRandom.hex(4)}")
    @suggestion_source = create(
      :source,
      authoritative: false,
      suggestion: true,
      slug: "sug-#{SecureRandom.hex(4)}"
    )

    @eng = build_language('Src')
    @dest = build_language('Dst')
    @other = build_language('Oth')

    # Picto with only a non-source placeholder label (bulk-upload style) — must be excluded
    @bulk = create(:picto, symbolset: @symbolset, source: @auth_source)
    @bulk.labels.first.update!(language: @other, source: @auth_source, text: 'Bulk Uploaded Symbol')

    # Pictos with authoritative source labels — must be included when dest missing
    @with_src_a = create(:picto, symbolset: @symbolset, source: @auth_source)
    @with_src_a.labels.first.update!(language: @eng, source: @auth_source, text: 'alpha')

    @with_src_b = create(:picto, symbolset: @symbolset, source: @auth_source)
    @with_src_b.labels.first.update!(language: @eng, source: @auth_source, text: 'bravo')

    # Source label present but already has authoritative dest — must be excluded from page
    @already_translated = create(:picto, symbolset: @symbolset, source: @auth_source)
    @already_translated.labels.first.update!(language: @eng, source: @auth_source, text: 'charlie')
    create(
      :label,
      picto: @already_translated,
      language: @dest,
      source: @auth_source,
      text: 'charlie-dest'
    )
  end

  test 'pictos_for_translation only includes source-labelled pictos without dest auth' do
    page_ids = @symbolset.pictos_for_translation(
      source_language: @eng,
      destination_language: @dest,
      limit: 35
    ).pluck(:id)

    assert_includes page_ids, @with_src_a.id
    assert_includes page_ids, @with_src_b.id
    assert_not_includes page_ids, @bulk.id
    assert_not_includes page_ids, @already_translated.id
  end

  test 'source_labels_for_batch_translation matches source-labelled pictos without any dest' do
    batch_picto_ids = @symbolset.source_labels_for_batch_translation(
      source_language: @eng,
      destination_language: @dest,
      limit: 35
    ).pluck(:picto_id)

    assert_includes batch_picto_ids, @with_src_a.id
    assert_includes batch_picto_ids, @with_src_b.id
    assert_not_includes batch_picto_ids, @bulk.id
    assert_not_includes batch_picto_ids, @already_translated.id
  end

  test 'pictos with only a dest suggestion still appear on the page for review' do
    create(
      :label,
      picto: @with_src_a,
      language: @dest,
      source: @suggestion_source,
      text: 'alpha-suggestion'
    )

    page_ids = @symbolset.pictos_for_translation(
      source_language: @eng,
      destination_language: @dest,
      limit: 35
    ).pluck(:id)

    batch_picto_ids = @symbolset.source_labels_for_batch_translation(
      source_language: @eng,
      destination_language: @dest,
      limit: 35
    ).pluck(:picto_id)

    assert_includes page_ids, @with_src_a.id, 'suggestions remain visible for publish'
    assert_not_includes batch_picto_ids, @with_src_a.id, 'already-suggested rows are not re-batched'
    assert_includes batch_picto_ids, @with_src_b.id
  end

  test 'page and batch candidate sets overlap for clean data' do
    page_ids = @symbolset.pictos_for_translation(
      source_language: @eng,
      destination_language: @dest,
      limit: 35
    ).pluck(:id)

    batch_ids = @symbolset.source_labels_for_batch_translation(
      source_language: @eng,
      destination_language: @dest,
      limit: 35
    ).pluck(:picto_id)

    assert_equal page_ids.sort, batch_ids.sort
  end

  private

  def build_language(prefix)
    token = SecureRandom.hex(2)
    code2 = format('%02d', SecureRandom.random_number(100))
    create(
      :language,
      azure_translate_supported: true,
      iso639_1: code2,
      iso639_3: token[0, 3],
      iso639_2b: "b#{code2}",
      iso639_2t: "t#{code2}",
      name: "#{prefix} #{token}",
      active: true,
      category: 'L',
      scope: 'I'
    )
  end
end
