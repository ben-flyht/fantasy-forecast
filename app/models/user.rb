class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ROLE_FORECASTER = "forecaster".freeze
  ROLE_ADMIN = "admin".freeze

  enum :role, {
    forecaster: ROLE_FORECASTER,
    admin: ROLE_ADMIN
  }

  # Callbacks
  before_validation :set_default_role, on: :create

  # Validations
  validates :username, presence: true, uniqueness: true

  # Associations
  has_many :forecasts, dependent: :destroy

  private

  def set_default_role
    self.role ||= :forecaster
  end
end
