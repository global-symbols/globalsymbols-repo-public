# frozen_string_literal: true

Doorkeeper::OpenidConnect.configure do
  issuer Rails.env.production? ? 'https://globalsymbols.com' : 'http://localhost:3000'

  signing_key <<~KEY
    -----BEGIN RSA PRIVATE KEY-----
    MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDTJALBWerTYBLP
    COywlNAyUddTjgl/tfDyQtKYo63wKzuY5eMgqTNBpcZoFUdZsOwI2l6NLA6TPKK2
    L3NAe4l1E2mmo2aYkvgAGyrNyMDxwBYa094D/DkYZKkx1MdnixxtU5EMeXrJokb9
    2wBkD29TUNiFkSDHuc3D3kcJNWb1CzAaNqRc1TZIqEX785donEDgP9cRR99RsgGK
    mKtfV5HaSwMD8yAE0LuFA3PPnlOZaBnyVUEhsq53dOkm/HWPBtaUzx7tSOTsOTAg
    nAPJhNEQex/iKy/rxOQntNXCGmrRqoK5M/KDDFHPQGzA63anlwIPf7TuMS0duEVf
    uY6JimuVAgMBAAECggEAQAp+I3NIfJB5Y/6K/AxHEdws+ZTtYKUozfJiuhV7Xote
    akPgHjnz6AeGJG+/0n6NOSoy35LrYNFVcPj3dimCSdZ3hymspr59JlsXIo+vpiPj
    EIQOpRrNno55mzm0ub1CBA8Cwcve6GWmLr1MYw0jcRvmcKzSSoIa3TwAQ9TEw7Hx
    ngwCus19fKXkHxKtOLWGgPxTHM9k3mLPHF0paq7u/oWKuJboUjFr+3LWklY3HOJs
    MvcPGmb2zbWC1b5NmRYeXxoDDh8bc+4+opuoxyY38MdH9p4L1/8l9uECJLSCKmPX
    X/+0ggtwP5QuTHkhzLwNGtLlmOiipUXjcy2Yb18rAQKBgQD6EnsYpuMuNbG0lbLO
    WQ1LpDoBaV4xnAh0eERoUSw4mSjh90Hv0jup0MWYr/NNfiM4BRI3vH+nlnu/Dnhf
    +O1pM14IWouBbHXfJEw627Z3DPA7RZQmTt+JLldXLr0AfVVM3KMUXaV09/6x9AFZ
    nhYdwlnZ394PqnMZeQIqA8iLoQKBgQDYJUfi41o3IWvAwR0o1Wo9CeoeYSAvS+hh
    EDaregkfIKwlPw1V5E9KdigKFu0fq08RghH+iGH3cQ34HF1n1i/Kmw40X1otf7CI
    OT/MMI5A/ad5Tw+ZxmC7guvkcuB006ZzjUwdkDeezfqJ4Rbz+2P39/F8bUMtV/X1
    g6QbBmS7dQKBgA1b4WGOwMIeMjEQci3dyf0Jd+PNai/CQx1ds2HTPEaFwA5aNBaI
    p5FJytR+ScQRAfajJrb9heBBBLlPH5UY6i3dhZ9yntM6JQ3XlY7rX9L6SPcRn3lw
    azab2CSbJZOaHm1tt/SFkCoweVWuUEgmTs4mLMCb2fQCSgXJVhlCfHshAoGAWryL
    yPuYS7yD948aJqIwzx7yYX50fGZpTxX3XVUFr0OQALLPbldB0gh4FoQ5VyobL0Zj
    N28ZcT7MlnOR4p1PwsYE2IeO27rW6Njfp2Ba132kaJCABBX7VbxIOsbe4yxWm/ud
    EGwSbWAa5PbRI+tMtDQp9AoKQWbDoiV5Jr8wWmECgYAzPburzFTBmaEgiwfFb+xO
    ERswQyLs784Btk9JHeFDJgXFSQPrTsLYpxY4uhc+FY1K9WFlv0dNlCXSj8ciBqZL
    M4V8sg2vIhGeZCk2loF48ySSQ1W4DL0HgRgY363APx0AUL0ek4gWCT4L2DOCXryG
    Mb//KA/1AybU+enYiXXzpw==
    -----END RSA PRIVATE KEY-----
  KEY
  
  signing_algorithm :rs256

  subject_types_supported [:public]

  resource_owner_from_access_token do |access_token|
    # Example implementation:
    # User.find_by(id: access_token.resource_owner_id)
    User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |resource_owner|
    # Example implementation:
    # resource_owner.current_sign_in_at
    resource_owner.current_sign_in_at
  end

  reauthenticate_resource_owner do |resource_owner, return_to|
    # Example implementation:
    # store_location_for resource_owner, return_to
    # sign_out resource_owner
    # redirect_to new_user_session_url
    store_location_for resource_owner, return_to
    sign_out resource_owner
    redirect_to new_user_session_url
  end

  # Depending on your configuration, a DoubleRenderError could be raised
  # if render/redirect_to is called at some point before this callback is executed.
  # To avoid the DoubleRenderError, you could add these two lines at the beginning
  #  of this callback: (Reference: https://github.com/rails/rails/issues/25106)
  #   self.response_body = nil
  #   @_response_body = nil
  select_account_for_resource_owner do |resource_owner, return_to|
    # Example implementation:
    # store_location_for resource_owner, return_to
    # redirect_to account_select_url
    store_location_for resource_owner, return_to
    redirect_to account_select_url
  end

  subject do |resource_owner, application|
    # Example implementation:
    resource_owner.id

    # or if you need pairwise subject identifier, implement like below:
    #Digest::SHA256.hexdigest("#{resource_owner.id}#{URI.parse(application.redirect_uri).host}#{'fskkif3lslkfg'}")
  end

  # Protocol to use when generating URIs for the discovery endpoint,
  # for example if you also use HTTPS in development
  # protocol do
  #   :https
  # end

  # Expiration time on or after which the ID Token MUST NOT be accepted for processing. (default 120 seconds).
  # expiration 600

  # Example claims:
  # claims do
  #   normal_claim :_foo_ do |resource_owner|
  #     resource_owner.foo
  #   end
  #
  #   normal_claim :_bar_ do |resource_owner|
  #     resource_owner.bar
  #   end
  # end
  # Claims will be returned according to the scopes requested by the client.
  # For details on how to present more details, see
  # https://github.com/doorkeeper-gem/doorkeeper-openid_connect#claims
  claims do
    claim :email do |resource_owner|
      resource_owner.email
    end

    claim :name do |resource_owner|
      "#{resource_owner.prename} #{resource_owner.surname}"
    end

    claim :given_name do |resource_owner|
      resource_owner.prename
    end

    claim :family_name do |resource_owner|
      resource_owner.surname
    end
  end
end
