class APIKeyMailer < ApplicationMailer
  def activation_email(api_key, raw_key)
    @api_key = api_key
    @raw_key = raw_key
    @activation_url = developer_authentication_activate_url(token: api_key.activation_token)

    mail(
      to: @api_key.email,
      subject: I18n.t('developer.authentication.activation_email_subject')
    )
  end
end

