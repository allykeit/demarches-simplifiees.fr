# frozen_string_literal: true

if ENV['PRO_CONNECT_BASE_URL'].present?
  discover = OpenIDConnect::Discovery::Provider::Config.discover!("#{ENV.fetch('PRO_CONNECT_BASE_URL')}/api/v2")

  PRO_CONNECT = {
    authorization_endpoint: discover.authorization_endpoint,
    client_id: ENV.fetch('PRO_CONNECT_ID'),
    end_session_endpoint: discover.end_session_endpoint,
    identifier: ENV.fetch('PRO_CONNECT_ID'),
    issuer: discover.issuer,
    jwks: discover.jwks,
    redirect_uri: ENV.fetch('PRO_CONNECT_REDIRECT'),
    secret: ENV.fetch('PRO_CONNECT_SECRET'),
    token_endpoint: discover.token_endpoint,
    userinfo_endpoint: discover.userinfo_endpoint
  }

  if ENV['PRO_CONNECT_GOUV_ID'].present?
    gouv_conf = PRO_CONNECT.dup

    gouv_conf[:client_id] = ENV.fetch('PRO_CONNECT_GOUV_ID')
    gouv_conf[:identifier] = ENV.fetch('PRO_CONNECT_GOUV_ID')
    gouv_conf[:secret] = ENV.fetch('PRO_CONNECT_GOUV_SECRET')
    gouv_conf[:redirect_uri] = ENV.fetch('PRO_CONNECT_GOUV_REDIRECT')

    PRO_CONNECT_GOUV = gouv_conf
  end
end
