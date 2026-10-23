class Manager < ApplicationRecord
  NICKNAME_LENGTH = 24

  has_many :pack_entries, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :nickname, with: ->(nickname) { nickname.squish }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :nickname, presence: true, length: { maximum: NICKNAME_LENGTH }

  generates_token_for :pack_link, expires_in: 7.days
end
