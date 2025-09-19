class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Enum for role
  enum :role, { prophet: 0, admin: 1 }

  # Validations
  validates :username, presence: true, uniqueness: true

  # Associations
  has_many :predictions, dependent: :destroy
end
