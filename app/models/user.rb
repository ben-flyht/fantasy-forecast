class User < ApplicationRecord
  NAME_LENGTH = 40
  ENTRY_NAME_LENGTH = 24

  has_many :selections, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :first_name, :last_name, :entry_name, with: ->(name) { name.squish.presence }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :first_name, :last_name, length: { maximum: NAME_LENGTH }
  validates :entry_name, length: { maximum: ENTRY_NAME_LENGTH }
  validates :entry_name, uniqueness: { case_sensitive: false }, allow_nil: true, if: :entry_name_changed?

  generates_token_for :pack_link, expires_in: 7.days

  def leaderboard_name = entry_name || initialled_name || "Unnamed entry"

  def named? = entry_name.present?

  private

  def initialled_name = ("#{first_name} #{last_name.first}." if first_name && last_name)
end
