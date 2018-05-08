# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# rubocop:disable Metrics/LineLength
Rails.application.config.session_store :cookie_store, key: '_vesta_session', domain: ".#{ENV.fetch('APPLICATION_HOST').gsub(/:\d+/, '')}"
