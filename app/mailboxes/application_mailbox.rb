class ApplicationMailbox < ActionMailbox::Base
  # Route e-mails addressed to support@* to SupportMailbox
  routing(/support@/i => :support)

  # Catch-all fallback (logs and bounces unknown addresses gracefully)
  routing :all => :support
end
