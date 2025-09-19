class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ROLE_PROPHET = "prophet".freeze
  ROLE_ADMIN = "admin".freeze

  enum :role, {
    prophet: ROLE_PROPHET,
    admin: ROLE_ADMIN
  }

  # Callbacks
  before_validation :set_default_role, on: :create

  # Validations
  validates :username, presence: true, uniqueness: true

  # Associations
  has_many :predictions, dependent: :destroy

  private

  def set_default_role
    self.role ||= :prophet
  end
end
