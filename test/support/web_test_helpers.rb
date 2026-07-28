# frozen_string_literal: true

module WebTestHelpers
  def published_picto_for_web
    Picto.joins(:symbolset, :labels, :images)
         .where(symbolsets: { status: Symbolset.statuses[:published] },
                archived: false,
                visibility: Picto.visibilities[:everybody])
         .first
  end

  def managed_symbolset_for(user)
    symbolset = create(:symbolset, users_count: 0, name: "Web Test #{SecureRandom.uuid}")
    create(:symbolset_user, user: user, symbolset: symbolset, role: :admin)
    symbolset
  end

  # Avoid FactoryBot Source sequence collisions with seeded `source-1` on the shared DB.
  def managed_picto_for(symbolset)
    source = Source.create!(
      name: "Web Picto Src #{SecureRandom.hex(4)}",
      slug: "web-picto-#{SecureRandom.hex(6)}",
      authoritative: true
    )
    label_source = Source.create!(
      name: "Web Label Src #{SecureRandom.hex(4)}",
      slug: "web-label-#{SecureRandom.hex(6)}",
      authoritative: true
    )
    language = Language.find_by!(iso639_1: 'en')

    picto = build(:picto, symbolset: symbolset, source: source, labels_count: 0, images_count: 1)
    picto.labels.build(
      text: "web-label-#{SecureRandom.hex(3)}",
      language: language,
      source: label_source
    )
    picto.save!
    picto
  end

  def grant_manager_access(user, symbolset)
    create(:symbolset_user, user: user, symbolset: symbolset, role: :admin)
    symbolset
  end

  # Adds an authoritative label in an Azure-supported language so translate can load.
  def add_translatable_label_to_symbolset(symbolset)
    token = SecureRandom.hex(4)
    code2 = format('%02d', SecureRandom.random_number(100))
    source = create(
      :source,
      authoritative: true,
      slug: "translate-test-#{token}",
      name: "Translate Test Source #{token}"
    )
    source_language = create(
      :language,
      azure_translate_supported: true,
      iso639_1: code2,
      iso639_3: "z#{code2}",
      iso639_2b: "b#{code2}",
      iso639_2t: "t#{code2}",
      name: "Translate Test #{token}",
      active: true,
      category: 'L',
      scope: 'I'
    )
    picto = create(:picto, symbolset: symbolset, source: source)
    picto.labels.first.update!(language: source_language, source: source, text: 'hello symbol')
    source_language
  end
end