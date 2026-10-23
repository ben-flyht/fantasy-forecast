class User < ApplicationRecord
  NAME_LENGTH = 40

  has_many :selections, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :first_name, :last_name, with: ->(name) { name.squish }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :first_name, :last_name, presence: true, length: { maximum: NAME_LENGTH }

  generates_token_for :pack_link, expires_in: 7.days

  def leaderboard_name = "#{first_name} #{last_name.first}."
end
