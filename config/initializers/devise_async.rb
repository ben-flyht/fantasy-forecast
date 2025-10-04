# Deliver Devise emails immediately instead of via background job
# This ensures emails are sent synchronously in production
Devise::Async.enabled = false if defined?(Devise::Async)
