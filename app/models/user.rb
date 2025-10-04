class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  # Validations
  validates :username, presence: true, uniqueness: true

  # Associations
  has_many :forecasts, dependent: :destroy
end
