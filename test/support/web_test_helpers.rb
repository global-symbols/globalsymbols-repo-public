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

  def grant_manager_access(user, symbolset)
    create(:symbolset_user, user: user, symbolset: symbolset, role: :admin)
    symbolset
  end
end