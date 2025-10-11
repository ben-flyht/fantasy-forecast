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
end
