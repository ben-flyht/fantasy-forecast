class Manager < ApplicationRecord
  has_many :pack_entries, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }

  generates_token_for :pack_link, expires_in: 7.days
end
