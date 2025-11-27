class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  # Validations
  validates :username, presence: true, uniqueness: true, format: {
    with: /\A[a-zA-Z0-9]+\z/,
    message: "can only contain letters and numbers (no spaces or special characters)"
  }

  # Associations
  has_many :forecasts, dependent: :destroy

  # Scopes
  scope :bots, -> { where(bot: true) }
  scope :humans, -> { where(bot: false) }

  # Class methods
  def self.find_or_create_bot(username)
    find_or_create_by!(username: username, bot: true) do |user|
      user.email = "#{username}@fantasyforecast.bot"
      user.password = SecureRandom.hex(32)
      user.confirmed_at = Time.current
    end
  end
end
