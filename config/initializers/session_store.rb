# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_vitals2_3_5_session',
  :secret      => 'e8bfb9fb46769eaf8c8c340d1038b6f92f128ef7d070eb76c2cbf3b684b93a8dc1d8ac6d08c69efc109161441355a94eea0f5685fdb49e13c3fe92ed25903e82'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
