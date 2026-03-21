class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('DEFAULT_FROM_EMAIL', 'system@globalsymbols.com')
  layout 'mailer'
end
