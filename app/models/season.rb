class Season < ApplicationRecord
  has_many :selections, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true

  def self.current = find_or_create_by!(name: name_for(Gameweek.ordered.first&.start_time || Time.current))

  def self.name_for(time)
    year = time.month >= 7 ? time.year : time.year - 1
    "#{year}/#{(year + 1).to_s.last(2)}"
  end
end
